import argparse
import io
import logging
import os

import requests
from azure.storage.filedatalake import DataLakeServiceClient
from dotenv import load_dotenv

load_dotenv()

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger(__name__)

STORAGE_ACCOUNT_NAME = os.environ["AZURE_STORAGE_ACCOUNT_NAME"]
STORAGE_ACCOUNT_KEY = os.environ["AZURE_STORAGE_ACCOUNT_KEY"]
TLC_BASE_URL = os.environ["TLC_BASE_URL"]
CITIBIKE_BASE_URL = os.environ["CITIBIKE_BASE_URL"]

SOURCE_CONFIG = {
    "taxi": {
        # Fichier TLC officiel, format parquet, ex: yellow_tripdata_2024-01.parquet
        "url_template": TLC_BASE_URL + "/yellow_tripdata_{month}.parquet",
        "extension": "parquet",
    },
    "bike": {
        # Citi Bike publie des zips mensuels contenant un ou plusieurs CSV
        "url_template": CITIBIKE_BASE_URL + "/{month_compact}-citibike-tripdata.csv.zip",
        "extension": "zip",
    },
}


def get_datalake_client() -> DataLakeServiceClient:
    account_url = f"https://{STORAGE_ACCOUNT_NAME}.dfs.core.windows.net"
    return DataLakeServiceClient(account_url=account_url, credential=STORAGE_ACCOUNT_KEY)


def download_source_file(source: str, month: str) -> bytes:
    config = SOURCE_CONFIG[source]
    month_compact = month.replace("-", "")
    url = config["url_template"].format(month=month, month_compact=month_compact)

    logger.info("Téléchargement depuis %s", url)
    response = requests.get(url, timeout=120, stream=True)
    response.raise_for_status()
    return response.content


def upload_to_landing(source: str, month: str, content: bytes) -> str:
    extension = SOURCE_CONFIG[source]["extension"]
    file_name = f"{source}_{month}.{extension}"
    directory_path = f"{source}/{month}"

    client = get_datalake_client()
    fs_client = client.get_file_system_client(file_system="landing")
    dir_client = fs_client.get_directory_client(directory_path)
    dir_client.create_directory()  # idempotent si déjà existant

    file_client = dir_client.create_file(file_name)
    file_client.upload_data(content, overwrite=True)

    full_path = f"landing/{directory_path}/{file_name}"
    logger.info("Uploadé : %s (%.1f MB)", full_path, len(content) / 1_000_000)
    return full_path


def main():
    parser = argparse.ArgumentParser(description="Charge un fichier mensuel TLC/Citi Bike vers ADLS landing")
    parser.add_argument("--source", choices=["taxi", "bike"], required=True)
    parser.add_argument("--month", required=True, help="Format YYYY-MM, ex: 2024-01")
    args = parser.parse_args()

    content = download_source_file(args.source, args.month)
    path = upload_to_landing(args.source, args.month, content)

    logger.info("Terminé. Fichier disponible pour Snowflake external stage : %s", path)
    logger.info("Prochaine étape : lance snowflake/03_load_raw.sql (COPY INTO) en adaptant le chemin.")


if __name__ == "__main__":
    main()

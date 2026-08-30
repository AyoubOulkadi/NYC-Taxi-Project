import argparse
import json
import logging
import os
import time
import uuid

import pandas as pd
from azure.eventhub import EventData, EventHubProducerClient
from dotenv import load_dotenv

load_dotenv()

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger(__name__)

EVENTHUB_CONN_STR = os.environ["EVENTHUB_PRODUCER_CONN_STR"]
EVENTHUB_NAME = os.environ["EVENTHUB_NAME"]
SPEED_FACTOR = int(os.environ.get("REPLAY_SPEED_FACTOR", 720))

TIME_COLUMNS = {
    "taxi": "pickup_datetime",
    "bike": "started_at",
}
ZONE_COLUMNS = {
    "taxi": "pickup_location_id",
    "bike": "start_station_id",
}


def load_trips(source: str, input_path: str) -> pd.DataFrame:
    if input_path.endswith(".parquet"):
        df = pd.read_parquet(input_path)
    else:
        df = pd.read_csv(input_path)

    time_col = TIME_COLUMNS[source]
    df[time_col] = pd.to_datetime(df[time_col])
    df = df.sort_values(time_col).reset_index(drop=True)
    return df


def build_event(source: str, row: pd.Series) -> dict:
    time_col = TIME_COLUMNS[source]
    zone_col = ZONE_COLUMNS[source]
    return {
        "event_id": str(uuid.uuid4()),
        "event_type": f"{source}_trip",
        # event_time = timestamp HISTORIQUE d'origine, pas le moment de publication
        "event_time": row[time_col].isoformat(),
        "zone_id": str(row.get(zone_col)),
        "payload": row.to_dict(default=str),
    }


def replay(source: str, df: pd.DataFrame, speed_factor: int) -> None:
    time_col = TIME_COLUMNS[source]
    producer = EventHubProducerClient.from_connection_string(
        conn_str=EVENTHUB_CONN_STR, eventhub_name=EVENTHUB_NAME
    )

    logger.info("Rejeu de %d trips (%s), facteur d'accélération x%d", len(df), source, speed_factor)
    prev_ts = None
    try:
        for _, row in df.iterrows():
            current_ts = row[time_col]
            if prev_ts is not None:
                delay_seconds = (current_ts - prev_ts).total_seconds() / speed_factor
                if delay_seconds > 0:
                    time.sleep(min(delay_seconds, 5))  # plafonné pour éviter des pauses trop longues en dev
            prev_ts = current_ts

            event = build_event(source, row)
            batch = producer.create_batch(partition_key=event["zone_id"])
            batch.add(EventData(json.dumps(event, default=str)))
            producer.send_batch(batch)

    finally:
        producer.close()
        logger.info("Rejeu terminé.")


def main():
    parser = argparse.ArgumentParser(description="Rejoue un fichier historique comme un flux d'événements")
    parser.add_argument("--source", choices=["taxi", "bike"], required=True)
    parser.add_argument("--input", required=True, help="Chemin local vers le fichier mensuel (parquet/csv)")
    parser.add_argument("--speed-factor", type=int, default=SPEED_FACTOR)
    parser.add_argument("--limit", type=int, default=None, help="Limiter le nb de trips (tests)")
    args = parser.parse_args()

    df = load_trips(args.source, args.input)
    if args.limit:
        df = df.head(args.limit)

    replay(args.source, df, args.speed_factor)


if __name__ == "__main__":
    main()

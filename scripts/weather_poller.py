import argparse
import json
import logging
import os
import time
import uuid
from datetime import datetime, timezone

import requests
from azure.eventhub import EventData, EventHubProducerClient
from dotenv import load_dotenv

load_dotenv()

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger(__name__)

WEATHER_API_URL = os.environ["WEATHER_API_URL"]
WEATHER_LAT = os.environ["WEATHER_LAT"]
WEATHER_LON = os.environ["WEATHER_LON"]
EVENTHUB_CONN_STR = os.environ["EVENTHUB_PRODUCER_CONN_STR"]
EVENTHUB_NAME = os.environ["EVENTHUB_NAME"]


def fetch_current_weather() -> dict:
    params = {
        "latitude": WEATHER_LAT,
        "longitude": WEATHER_LON,
        "current": "temperature_2m,precipitation,wind_speed_10m,weather_code",
    }
    response = requests.get(WEATHER_API_URL, params=params, timeout=30)
    response.raise_for_status()
    return response.json()


def to_event(raw_weather: dict) -> dict:
    current = raw_weather.get("current", {})
    return {
        "event_id": str(uuid.uuid4()),
        "event_type": "weather",
        # event_time = temps réel de l'observation (source authentiquement live)
        "event_time": datetime.now(timezone.utc).isoformat(),
        "zone_id": None,  # observation ville entière, pas rattachée à une zone spécifique
        "payload": {
            "temperature_c": current.get("temperature_2m"),
            "precipitation_mm": current.get("precipitation"),
            "wind_speed_kmh": current.get("wind_speed_10m"),
            "weather_code": current.get("weather_code"),
        },
    }


def send_to_eventhub(producer: EventHubProducerClient, event: dict) -> None:
    batch = producer.create_batch()
    batch.add(EventData(json.dumps(event)))
    producer.send_batch(batch)
    logger.info("Événement météo envoyé : %s", event["event_id"])


def main():
    parser = argparse.ArgumentParser(description="Poller météo temps réel -> Event Hubs")
    parser.add_argument("--interval", type=int, default=300, help="Intervalle en secondes")
    args = parser.parse_args()

    producer = EventHubProducerClient.from_connection_string(
        conn_str=EVENTHUB_CONN_STR, eventhub_name=EVENTHUB_NAME
    )

    logger.info("Démarrage du poller météo (intervalle=%ss)", args.interval)
    try:
        while True:
            try:
                raw_weather = fetch_current_weather()
                event = to_event(raw_weather)
                send_to_eventhub(producer, event)
            except Exception:
                logger.exception("Échec du cycle de polling météo — nouvelle tentative au prochain cycle")
            time.sleep(args.interval)
    finally:
        producer.close()


if __name__ == "__main__":
    main()

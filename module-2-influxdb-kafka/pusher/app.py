import os
import time
import random
from datetime import datetime, timezone

from influxdb_client import InfluxDBClient, Point, WriteOptions
from influxdb_client.client.write_api import SYNCHRONOUS

INFLUX_URL = os.getenv("INFLUX_URL", "http://influxdb:8086")
INFLUX_ORG = os.getenv("INFLUX_ORG", "ISIMA")
INFLUX_TOKEN = os.getenv("INFLUX_TOKEN")
INFLUX_BUCKET = os.getenv("INFLUX_BUCKET", "weather")
INTERVAL_SECONDS = int(os.getenv("INTERVAL_SECONDS", "5"))

def build_point():
    # Exemple simple : température et humidité simulées
    temperature = round(random.uniform(18.0, 28.0), 2)
    humidity = round(random.uniform(30.0, 70.0), 1)
    return (
        Point("weather")
        .tag("source", "simulator")
        .field("temperature_c", temperature)
        .field("humidity_pct", humidity)
        .time(datetime.now(timezone.utc))
    )

def main():
    if not INFLUX_TOKEN:
        raise SystemExit("Missing INFLUX_TOKEN environment variable")

    # Connexion et write client
    client = InfluxDBClient(url=INFLUX_URL, token=INFLUX_TOKEN, org=INFLUX_ORG, timeout=10_000)
    write_api = client.write_api(write_options=SYNCHRONOUS)

    # Boucle d’écriture infinie, 1 point / INTERVAL_SECONDS
    backoff = 1
    while True:
        try:
            p = build_point()
            write_api.write(bucket=INFLUX_BUCKET, org=INFLUX_ORG, record=p)
            print(f"[{datetime.utcnow().isoformat()}Z] wrote point to bucket '{INFLUX_BUCKET}'")
            backoff = 1  # reset après succès
            time.sleep(INTERVAL_SECONDS)
        except Exception as e:
            print(f"write failed: {e} (retrying in {backoff}s)")
            time.sleep(backoff)
            backoff = min(backoff * 2, 60)  # backoff exponentiel max 60s

if __name__ == "__main__":
    main()
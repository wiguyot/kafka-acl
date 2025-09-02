import os
import time
import datetime as dt
from influxdb_client import InfluxDBClient
from influxdb_client.client.exceptions import InfluxDBError

URL = os.getenv("INFLUX_URL", "http://localhost:8086")
ORG = os.getenv("INFLUX_ORG", "ISIMA")
BUCKET = os.getenv("INFLUX_BUCKET", "weather")
TOKEN = os.getenv("INFLUX_TOKEN")
SLEEP = float(os.getenv("WATCH_INTERVAL_SECONDS", "1"))

if not TOKEN:
    print("❌ INFLUX_TOKEN manquant ; définis INFLUX_TOKEN dans docker-compose.")
    raise SystemExit(1)

client = InfluxDBClient(url=URL, token=TOKEN, org=ORG, timeout=10_000)
query_api = client.query_api()

# petit wait-for-influx
for i in range(30):
    try:
        _ = client.ready()  # ping interne
        break
    except Exception as e:
        if i == 0:
            print("⏳ Attente qu'InfluxDB soit prêt…")
        time.sleep(1)
else:
    print("❌ InfluxDB ne répond pas.")
    raise SystemExit(2)

print(f"👀 Watching bucket={BUCKET} org={ORG} url={URL}")

# On démarre à 'now - 10m' pour rattraper le backlog
last_ts = dt.datetime.now(dt.timezone.utc) - dt.timedelta(minutes=10)

while True:
    # on interroge strictement après last_ts
    start_iso = last_ts.isoformat()
    flux = f'''
    from(bucket: "{BUCKET}")
      |> range(start: time(v: "{start_iso}"))
      |> filter(fn: (r) => r["_measurement"] == "weather")
      |> filter(fn: (r) => r["_field"] == "temperature_c" or r["_field"] == "humidity_pct")
      |> sort(columns: ["_time"], desc: false)
    '''
    try:
        tables = query_api.query(flux)
        newest = last_ts
        count = 0
        for table in tables:
            for rec in table.records:
                ts = rec.get_time()  # timezone-aware datetime
                if ts <= last_ts:
                    continue
                field = rec.get_field()
                val = rec.get_value()
                loc = rec.values.get("location", "")
                print(f"[{ts.isoformat()}] {field}={val} {loc}".strip())
                count += 1
                if ts > newest:
                    newest = ts
        if count:
            last_ts = newest
        time.sleep(SLEEP)
    except InfluxDBError as e:
        # 401/403 → souvent token/orga/bucket
        print(f"❌ InfluxDBError: {e}. Vérifie token/org/bucket.")
        time.sleep(3)
    except Exception as e:
        print(f"⚠️  Erreur watcher: {e}")
        time.sleep(3)
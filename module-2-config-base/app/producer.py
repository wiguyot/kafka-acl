import os, json, random, time
from datetime import datetime, timezone
from confluent_kafka import Producer

conf = {
    "bootstrap.servers": os.getenv("BOOTSTRAP","kafka:19092"),
    "security.protocol": "SASL_SSL",
    "sasl.mechanism": "PLAIN",
    "sasl.username": os.getenv("K_USERNAME"),
    "sasl.password": os.getenv("K_PASSWORD"),
    "ssl.ca.location": os.getenv("SSL_CA","/app/ca.crt"),
    "client.id": "py-producer",
    "acks": "all",
}
p = Producer(conf)
topic = os.getenv("TOPIC","weather")

def delivery(err, msg):
    if err:
        print(f"❌ Delivery failed: {err}")
    else:
        print(f"✅ Sent to {msg.topic()}[{msg.partition()}] offset {msg.offset()}")

print("🚀 Producer started (5s interval, 5–25°C)…")
while True:
    temp = round(random.uniform(5.0, 25.0), 2)
    print("Définition du PAYLOAD => ", temp)
    payload = {
        "ts": datetime.now(timezone.utc).isoformat(),
        "sensor": "demo-1",
        "temperature_c": temp
    }
    p.produce(topic, json.dumps(payload).encode("utf-8"), callback=delivery)
    p.poll(0)
    time.sleep(5)
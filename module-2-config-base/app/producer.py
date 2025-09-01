import os, json, random, time
from datetime import datetime, timezone
from confluent_kafka import Producer

conf = {
    "bootstrap.servers": os.getenv("BOOTSTRAP","kafka:19092"),
    "security.protocol": "SASL_SSL",
    "sasl.mechanism": "PLAIN",
    "sasl.username": os.getenv("K_USERNAME","user1"),
    "sasl.password": os.getenv("K_PASSWORD","user1-secret"),
    "ssl.ca.location": os.getenv("SSL_CA","/app/ca.crt"),
    "client.id": "py-producer",
    "acks": "all",
}
print("Avant init du producteur")
p = Producer(conf)
print("Défition du TOPIC via lecture de la variable d'environnement")
topic = os.getenv("TOPIC","weather")

def delivery(err, msg):
    if err:
        print(f"❌ Delivery failed: {err}")
    else:
        print(f"✅ Sent to {msg.topic()}[{msg.partition()}] offset {msg.offset()}")

print("🚀 Producer started (5s interval, 5–25°C)…")
while True:
    temp = round(random.uniform(5.0, 25.0), 2)
    print("Définition du PAYLOAD")
    payload = {
        "ts": datetime.now(timezone.utc).isoformat(),
        "sensor": "demo-1",
        "temperature_c": temp
    }
    print("Production du payload")
    p.produce(topic, json.dumps(payload).encode("utf-8"), callback=delivery)
    print("On fait le poll(0)")
    p.poll(0)
    print("on s'endore pour 5 secondes")
    time.sleep(5)
import os, json
from confluent_kafka import Consumer, KafkaException

conf = {
    "bootstrap.servers": os.getenv("BOOTSTRAP","kafka:19092"),
    "security.protocol": "SASL_SSL",
    "sasl.mechanism": "PLAIN",
    "sasl.username": os.getenv("K_USERNAME"),
    "sasl.password": os.getenv("K_PASSWORD"),
    "ssl.ca.location": os.getenv("SSL_CA","/app/ca.crt"),
    "group.id": os.getenv("GROUP","weather-group"),
    "auto.offset.reset": "earliest",
    "enable.auto.commit": "true",
    "client.id": "py-consumer",
}
c = Consumer(conf)
topic = os.getenv("TOPIC","weather")
c.subscribe([topic])
print("👂 Consumer started…")
try:
    while True:
        msg = c.poll(1.0)
        if msg is None: 
            continue
        if msg.error():
            raise KafkaException(msg.error())
        data = json.loads(msg.value())
        print(f"📥 {msg.topic()}[{msg.partition()}]@{msg.offset()} -> {data}")
except KeyboardInterrupt:
    pass
finally:
    c.close()
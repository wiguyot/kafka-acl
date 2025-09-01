#!/bin/bash

# Wait for Kafka broker to become available
until /opt/bitnami/kafka/bin/kafka-broker-api-versions.sh --bootstrap-server kafka:29092 &>/dev/null; do
  echo "Waiting for Kafka broker..."
  sleep 5
done


/opt/bitnami/kafka/bin/kafka-topics.sh --bootstrap-server kafka:29092 --create --topic weather --partitions 1 --replication-factor 1

/opt/bitnami/kafka/bin/kafka-acls.sh --bootstrap-server kafka:29092 --add --allow-principal User:user1 --operation Read --topic weather
/opt/bitnami/kafka/bin/kafka-acls.sh --bootstrap-server kafka:29092 --add --allow-principal User:user1 --operation Write --topic weather

/opt/bitnami/kafka/bin/kafka-acls.sh --bootstrap-server kafka:29092 --add --allow-principal User:admin --operation All --topic weather
/opt/bitnami/kafka/bin/kafka-acls.sh --bootstrap-server kafka:29092 --add --allow-principal User:admin --operation All --cluster
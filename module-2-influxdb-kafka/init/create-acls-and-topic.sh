#!/usr/bin/env bash
set -euo pipefail

# Assure la présence des CLI Kafka Bitnami dans le PATH
export PATH="/opt/bitnami/kafka/bin:$PATH"

BS="kafka:29092"   # listener INTERNAL (PLAINTEXT) intra-réseau Docker

echo "⏳ Attente brève que le broker réponde…"
sleep 2

echo "🔧 Création (idempotente) du topic 'weather'…"
kafka-topics.sh --bootstrap-server "$BS" \
  --create --if-not-exists \
  --topic weather --partitions 1 --replication-factor 1

echo "🔐 ACLs pour weather_user (READ/DESCRIBE sur topic) + READ sur group 'weather-group'…"
kafka-acls.sh --bootstrap-server "$BS" \
  --add --allow-principal User:weather_user \
  --operation READ --operation DESCRIBE --topic weather

kafka-acls.sh --bootstrap-server "$BS" \
  --add --allow-principal User:user1 \
  --add --allow-principal User:weather_user \

echo "🛠  ACLs admin (ALL sur topic + CLUSTER)…"
kafka-acls.sh --bootstrap-server "$BS" \
  --add --allow-principal User:admin \
  --operation ALL --topic weather

kafka-acls.sh --bootstrap-server "$BS" \
  --add --allow-principal User:admin \
  --operation ALL --cluster

echo "✅ Init ACLs/Topic terminé."
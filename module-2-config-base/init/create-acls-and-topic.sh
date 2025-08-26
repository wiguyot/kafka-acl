#!/usr/bin/env bash
set -euo pipefail
export PATH="/opt/bitnami/kafka/bin:$PATH"

BOOT="kafka:19092"        # listener EXTERNAL en TLS
CFG="/tmp/client.properties"

cat > "$CFG" <<'EOF'
client.id=init-acls
security.protocol=SSL

# Truststore en PEM : doit contenir les CA (pas un JKS)
ssl.truststore.type=PEM
ssl.truststore.certificates=/opt/bitnami/kafka/config/certs/ca.truststore.pem

# Si le CN/SAN du cert serveur ne matche pas exactement l'hôte, décommente :
# ssl.endpoint.identification.algorithm=

# (Optionnel mTLS, seulement si le broker l’exige)
# ssl.keystore.type=PEM
# ssl.keystore.certificate.chain=/opt/bitnami/kafka/config/certs/client.chain.pem
# ssl.keystore.key=/opt/bitnami/kafka/config/certs/client.key.pem
# ssl.key.password=xxxxxxxx
EOF

# Attendre le port TLS
timeout 30 bash -c 'until echo >/dev/tcp/kafka/19092; do sleep 1; done'

kafka-topics.sh --bootstrap-server "$BOOT" --command-config "$CFG" \
  --create --if-not-exists \
  --topic weather --partitions 1 --replication-factor 1

kafka-acls.sh --bootstrap-server "$BOOT" --command-config "$CFG" \
  --add --allow-principal User:user1 --operation WRITE --topic weather
kafka-acls.sh --bootstrap-server "$BOOT" --command-config "$CFG" \
  --add --allow-principal User:user1 --operation READ --topic weather
kafka-acls.sh --bootstrap-server "$BOOT" --command-config "$CFG" \
  --add --allow-principal User:user1 --operation READ --group weather-group

echo "✅ Topic & ACLs créés via EXTERNAL (TLS)"
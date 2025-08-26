#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

DIR="./conf/certs"
mkdir -p "$DIR"

# 1) CA auto-signée
openssl req -new -newkey rsa:4096 -x509 -sha256 -days 3650 -nodes \
  -subj "/CN=Kafka-Local-CA" \
  -keyout "${DIR}/ca.key" -out "${DIR}/kafka.truststore.pem"

# 2) Clé serveur
openssl genrsa -out "${DIR}/kafka.keystore.key" 4096

# 3) CSR + SAN (kafka, localhost)
cat > "${DIR}/csr.conf" <<'EOF'
[ req ]
default_md = sha256
distinguished_name = dn
req_extensions = v3_req
prompt = no
[ dn ]
CN = kafka
O = Local
OU = Dev
L = CFD
ST = ARA
C = FR
[ v3_req ]
subjectAltName = @alt_names
[ alt_names ]
DNS.1 = kafka
DNS.2 = localhost
EOF

openssl req -new -key "${DIR}/kafka.keystore.key" -out "${DIR}/server.csr" -config "${DIR}/csr.conf"

# 4) Cert serveur signé par la CA (chaîne simple)
cat > "${DIR}/ca.ext" <<'EOF'
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, keyEncipherment
subjectAltName = @alt_names
[alt_names]
DNS.1 = kafka
DNS.2 = localhost
EOF

openssl x509 -req -in "${DIR}/server.csr" -CA "${DIR}/kafka.truststore.pem" -CAkey "${DIR}/ca.key" \
  -CAcreateserial -out "${DIR}/kafka.keystore.pem" -days 3650 -sha256 -extfile "${DIR}/ca.ext"

chmod 600 "${DIR}/kafka.keystore.key"
echo "✅ Certs PEM générés dans ${DIR}"
ls -l "${DIR}"/kafka.keystore.pem "${DIR}"/kafka.keystore.key "${DIR}"/kafka.truststore.pem
#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------------------------
#  Génère des certificats PEM pour Kafka (Bitnami)
#  - CA (self-signed)
#  - Cert serveur signé par la CA, avec SAN pour kafka + localhost
#  - Sorties attendues par l'image Bitnami:
#       kafka.keystore.key   (clé privée serveur)
#       kafka.keystore.pem   (cert serveur + CA concaténés)
#       kafka.truststore.pem (cert CA)
#
#  Usage (par défaut SAN: kafka, localhost, 127.0.0.1):
#     ./gen-certs.sh [CN] [DNS_ALT1] [DNS_ALT2] ...
#     ex: ./gen-certs.sh kafka localhost
#
#  Remarque: le CN par défaut est "kafka".
# ------------------------------------------------------------------------------

CN="${1:-kafka}"
shift || true
SAN_DNS=("DNS:${CN}" "DNS:localhost" "IP:127.0.0.1")
# Ajoute les arguments restants comme SAN supplémentaires (DNS:xxx)
for arg in "$@"; do
  if [[ "$arg" =~ ^IP:|^DNS: ]]; then
    SAN_DNS+=("$arg")
  else
    SAN_DNS+=("DNS:${arg}")
  fi
done

OUT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$OUT_DIR"

echo ">> Génération dans: $OUT_DIR"
echo ">> CN=${CN}"
echo ">> SAN=${SAN_DNS[*]}"

# Fichiers de sortie attendus par Bitnami
KEY_SERVER="kafka.keystore.key"
CRT_SERVER="kafka.keystore.pem"       # contiendra cert serveur + CA (chaîne)
CRT_CA="kafka.truststore.pem"         # CA (truststore PEM)

# Fichiers intermédiaires
KEY_CA="ca.key"
CRT_CA_TMP="ca.crt"
KEY_TMP="server.key"
CSR_TMP="server.csr"
CRT_SERVER_ONLY="server.crt"
OPENSSL_CNF="san.cnf"

# Nettoyage ancien
rm -f "$KEY_SERVER" "$CRT_SERVER" "$CRT_CA" "$KEY_CA" "$CRT_CA_TMP" \
      "$KEY_TMP" "$CSR_TMP" "$CRT_SERVER_ONLY" "$OPENSSL_CNF"

# 1) Génère une CA (self-signed) pour DEV
openssl genrsa -out "$KEY_CA" 2048
openssl req -x509 -new -nodes -key "$KEY_CA" -sha256 -days 365 \
  -subj "/CN=dev-kafka-ca/O=Dev/OU=Dev" \
  -out "$CRT_CA_TMP"

# 2) Génère la clé serveur + CSR
openssl genrsa -out "$KEY_TMP" 2048

# Fichier openssl.cnf avec SAN
{
  echo "[ req ]"
  echo "default_bits       = 2048"
  echo "distinguished_name = req_distinguished_name"
  echo "req_extensions     = req_ext"
  echo "prompt             = no"
  echo
  echo "[ req_distinguished_name ]"
  echo "CN = ${CN}"
  echo "O  = Dev"
  echo "OU = Dev"
  echo
  echo "[ req_ext ]"
  echo "subjectAltName = ${SAN_DNS[*]// /,}"
} > "$OPENSSL_CNF"

openssl req -new -key "$KEY_TMP" -out "$CSR_TMP" -config "$OPENSSL_CNF"

# 3) Signe le cert serveur avec la CA + SAN
openssl x509 -req -in "$CSR_TMP" -CA "$CRT_CA_TMP" -CAkey "$KEY_CA" \
  -CAcreateserial -out "$CRT_SERVER_ONLY" -days 365 -sha256 \
  -extfile "$OPENSSL_CNF" -extensions req_ext

# 4) Assemblage pour Bitnami:
#    - kafka.keystore.key  : clé privée serveur
#    - kafka.keystore.pem  : cert serveur + CA (chaîne)
#    - kafka.truststore.pem: CA
cp "$KEY_TMP" "$KEY_SERVER"
cat "$CRT_SERVER_ONLY" "$CRT_CA_TMP" > "$CRT_SERVER"
cp "$CRT_CA_TMP" "$CRT_CA"

# Permissions (lecture seule)
chmod 600 "$KEY_SERVER" "$CRT_SERVER" "$CRT_CA"

echo ">> OK."
echo "   - $KEY_SERVER"
echo "   - $CRT_SERVER"
echo "   - $CRT_CA"
echo
echo "Tu peux maintenant lancer: docker compose up -d kafka"
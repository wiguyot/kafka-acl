#!/usr/bin/env bash
set -euo pipefail

echo "🔐 Création idempotente des tokens RO/RW pour le bucket 'weather'…"

# Paramètres requis (passés via environment du service influx-init)
: "${INFLUX_HOST:?missing INFLUX_HOST}"
: "${INFLUX_ORG:?missing INFLUX_ORG}"
: "${INFLUX_TOKEN:?missing INFLUX_TOKEN}"

# (petite attente si besoin, selon la latence du healthcheck)
sleep 1

# Récupération de l'ID du bucket 'weather'
BUCKET_ID="$(influx bucket list \
  --org "$INFLUX_ORG" \
  --host "$INFLUX_HOST" \
  --token "$INFLUX_TOKEN" \
  --name weather --hide-headers | awk '{print $1}')"

if [[ -z "${BUCKET_ID}" ]]; then
  echo "❌ Bucket 'weather' introuvable (org=$INFLUX_ORG)."
  exit 1
fi
echo "✅ Bucket weather id: ${BUCKET_ID}"

mkdir -p /init

# Utilitaire : récupérer un token existant par description
get_token_by_desc () {
  local desc="$1"
  influx auth list \
    --org "$INFLUX_ORG" --host "$INFLUX_HOST" --token "$INFLUX_TOKEN" \
    --json \
  | tr '\n' ' ' \
  | sed 's/},{/}\n{/g' \
  | awk -v d="$desc" '
      $0 ~ "\"description\":\"" d "\"" {
        if (match($0, /"token":"([^"]+)"/, a)) { print a[1]; exit }
      }'
}

# -------- Token RO (lecture seule) ----------
if [[ -f /init/weather_ro_token.env ]]; then
  echo "ℹ️  Token RO déjà matérialisé (/init/weather_ro_token.env) – réutilisation."
else
  EXISTING_RO="$(get_token_by_desc "RO weather token" || true)"
  if [[ -n "${EXISTING_RO:-}" ]]; then
    echo "ℹ️  Token RO existant trouvé – réutilisation."
    echo "INFLUX_WEATHER_RO_TOKEN=${EXISTING_RO}" | tee /init/weather_ro_token.env
  else
    RO_JSON="$(influx auth create \
      --org "$INFLUX_ORG" --host "$INFLUX_HOST" --token "$INFLUX_TOKEN" \
      --read-bucket "$BUCKET_ID" \
      --description "RO weather token" \
      --json)"
    RO_TOKEN="$(echo "$RO_JSON" | sed -n 's/.*"token":"\([^"]*\)".*/\1/p')"
    echo "INFLUX_WEATHER_RO_TOKEN=${RO_TOKEN}" | tee /init/weather_ro_token.env
    echo "✅ Token RO créé."
  fi
fi

# -------- Token RW (lecture + écriture) ----------
if [[ -f /init/weather_rw_token.env ]]; then
  echo "ℹ️  Token RW déjà matérialisé (/init/weather_rw_token.env) – réutilisation."
else
  EXISTING_RW="$(get_token_by_desc "RW weather token" || true)"
  if [[ -n "${EXISTING_RW:-}" ]]; then
    echo "ℹ️  Token RW existant trouvé – réutilisation."
    echo "INFLUX_WEATHER_RW_TOKEN=${EXISTING_RW}" | tee /init/weather_rw_token.env
  else
    RW_JSON="$(influx auth create \
      --org "$INFLUX_ORG" --host "$INFLUX_HOST" --token "$INFLUX_TOKEN" \
      --read-bucket "$BUCKET_ID" --write-bucket "$BUCKET_ID" \
      --description "RW weather token" \
      --json)"
    RW_TOKEN="$(echo "$RW_JSON" | sed -n 's/.*"token":"\([^"]*\)".*/\1/p')"
    echo "INFLUX_WEATHER_RW_TOKEN=${RW_TOKEN}" | tee /init/weather_rw_token.env
    echo "✅ Token RW créé."
  fi
fi

# (Optionnel) Vérifier que la measurement existe (ou écrire un point seed)
# Remarque: InfluxDB 2 crée les measurements à l'écriture.
# Ci-dessous, on écrit un point « seed » si besoin.
if ! influx query --org "$INFLUX_ORG" --host "$INFLUX_HOST" --token "$INFLUX_TOKEN" \
  'import "influxdata/influxdb/schema"
   schema.measurements(bucket: "weather")' | grep -q '^weather$'; then
  echo "weather,source=bootstrap temperature=0i" | influx write \
    --org "$INFLUX_ORG" --host "$INFLUX_HOST" --token "$INFLUX_TOKEN" \
    --bucket weather --precision s
  echo "ℹ️  Measurement 'weather' matérialisée avec un point seed."
fi

echo "🎉 Terminé. Tokens disponibles dans le volume monté /init (./influx-bootstrap côté host)."
#!/usr/bin/env bash
# Kopieert de release-signing keys van ~/.android-certs/ naar de build-tree
# (src/vendor/evolution-priv/keys/) en schrijft keys.mk. EvolutionX pikt dit
# automatisch op via `-include vendor/evolution-priv/keys/keys.mk` in
# vendor/lineage/config/evolution.mk → de build wordt met release-keys getekend.
#
# Gebruik: ./setup-keys.sh
set -euo pipefail
cd "$(dirname "$0")"

CERTS="${ANDROID_CERTS:-$HOME/.android-certs}"
DEST="src/vendor/evolution-priv/keys"

if [ ! -d "$CERTS" ]; then
  echo "Fout: geen keys gevonden in $CERTS." >&2
  echo "Genereer ze eerst (development/tools/make_key), of zet ANDROID_CERTS." >&2
  exit 1
fi

mkdir -p "$DEST"
n=0
for f in "$CERTS"/*.pk8 "$CERTS"/*.x509.pem; do
  [ -e "$f" ] || continue
  cp -f "$f" "$DEST/" && n=$((n+1))
done

cat > "$DEST/keys.mk" <<'EOF'
# Release signing keys (EvolutionX).
PRODUCT_DEFAULT_DEV_CERTIFICATE := vendor/evolution-priv/keys/releasekey
PRODUCT_EXTRA_RECOVERY_KEYS := vendor/evolution-priv/keys/releasekey
EOF

echo "OK: $n keys gekopieerd naar $DEST/ + keys.mk geschreven."
echo "De volgende build wordt automatisch met release-keys getekend."

#!/usr/bin/env bash
# Bouwt de EvolutionX-ROM voor garnet (sync + build) in de bestaande Docker-container.
set -euo pipefail
cd "$(dirname "$0")"

# Start de container als die nog niet draait
if ! docker ps --format '{{.Names}}' | grep -qx garnet-builder; then
  echo "Starting garnet-builder container..."
  docker run -d --name garnet-builder \
    -v "$(pwd)/src:/src" \
    -v "$(pwd)/ccache:/ccache" \
    evolutionx-builder sleep infinity
fi

LOG="$(pwd)/src/build-$(date +%Y%m%d-%H%M%S).log"

docker exec garnet-builder bash -c '
  set -e
  cd /src
  export USE_CCACHE=1 CCACHE_DIR=/ccache CCACHE_EXEC=/usr/bin/ccache

  echo "=== repo sync ==="
  repo sync -c -j16 --force-sync --no-clone-bundle --no-tags

  echo "=== build (m evolution -j16) ==="
  source build/envsetup.sh
  lunch lineage_garnet-userdebug
  ccache -M 50G
  m evolution -j16
' 2>&1 | tee "$LOG"

echo
echo "Log: $LOG"
echo "Output zip: $(pwd)/src/out/target/product/garnet/EvolutionX-16.0-*-garnet-11.11-Unofficial.zip"

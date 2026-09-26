#!/usr/bin/env bash
# Synct de device-tree fork (Hayqe/device_xiaomi_garnet) met upstream
# (Evolution-X-Devices/device_xiaomi_garnet), branch bka. Rebased de eigen
# fork-commits (OTA-overlay + AVB-key) op de nieuwste upstream en pusht.
#
# Gebruik: ./sync-device-tree.sh   (draai vóór ./build.sh als je upstream-fixes wilt)
set -euo pipefail
cd "$(dirname "$0")"

DT="src/device/xiaomi/garnet"
cd "$DT"

echo "Fetch upstream bka..."
git fetch evo-devices bka

if git merge-base --is-ancestor evo-devices/bka HEAD; then
  echo "OK: geen nieuwe upstream-commits — fork is up-to-date."
  exit 0
fi

echo "Nieuwe upstream-commits gevonden — rebase de eigen fork-commits erop..."
BASE="$(git merge-base HEAD evo-devices/bka)"
git rebase --onto evo-devices/bka "$BASE" HEAD

echo "Push naar de fork..."
git fetch fork bka
git push fork HEAD:bka --force-with-lease

echo "Klaar. Draai daarna ./build.sh (of repo sync) om de geüpdatete fork te gebruiken."

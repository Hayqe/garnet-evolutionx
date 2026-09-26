# EvolutionX voor garnet — zelfbouw

Zelfgebouwde **EvolutionX 11.11 (Android 16) met Google Apps** voor de
**Xiaomi Redmi Note 13 Pro 5G / Poco X6 5G** (codename `garnet`).

De ROM wordt gebouwd uit de officiële EvolutionX-bron (branch `bka` = Android 16),
met de garnet device tree en alle device-specifieke blobs. Google Apps zitten er
standaard in (`WITH_GMS=true`).

## Resultaat

De flashbare ROM staat na een build op:

```
src/out/target/product/garnet/EvolutionX-16.0-<datum>-garnet-11.11-Unofficial.zip
```

> ⚠️ Dit is een **Unofficial** build, getekend met je eigen release keys (zie
> [Signing](#signing)). **Play Integrity / SafetyNet werkt niet out-of-the-box** —
> Google Pay, sommige bank-apps en Netflix kunnen weigeren (op te lossen met een
> Play Integrity Fix).

---

## Opzet / architectuur

| Onderdeel | Detail |
|---|---|
| Host | Ubuntu 26.04 LTS |
| Build-omgeving | Docker-container met **Ubuntu 24.04** (AOSP ondersteunt 24.04 officieel, niet 26.04) |
| Build-image | `evolutionx-builder` (zie `Dockerfile`) |
| Container | `garnet-builder` (persistent, bind-mounts hieronder) |
| Broncode | `src/` → gemount op `/src` in de container |
| Ccache | `ccache/` → gemount op `/ccache` (50 GB) |
| Manifest | EvolutionX branch `bka` = Android 16 (`android-16.0.0_r4`) |
| Device tree | fork van `Evolution-X-Devices/device_xiaomi_garnet` → `Hayqe/device_xiaomi_garnet` (productnaam `lineage_garnet`) |
| Build-target | `lunch lineage_garnet-userdebug` → `m evolution` |

### Waarom een local_manifest nodig is

De garnet device tree staat **niet** in de hoofdmanifest. Hij wordt via
`src/.repo/local_manifests/garnet.xml` toegevoegd, samen met alle dependencies
(vendor-blobs, kernel `sm7435`, modules, devicetrees, `hardware/xiaomi`,
`hardware/dolby`, MIUI-camera, GameBar).

Belangrijk: de remotes `evo-devices`, `github-non-los` en `gitlab` zijn al in de
EvolutionX-manifest (`snippets/evolution.xml`) gedefinieerd. Definieer ze **niet**
opnieuw in de local_manifest — dat geeft een "remote already exists"-fout.

De vendor-blobs zijn **voorgebouwd** (`vendor_xiaomi_garnet`); je hoeft dus niets
vanaf het toestel te extraheren.

---

## Vereisten (host)

- **Docker** (draaiend).
- **Schijfruimte**: bron ~178 GB + build-output ~100 GB + ccache 50 GB → reken op
  ≥ 400 GB vrij.
- **RAM**: de Soong-analyse piekt op ~30-40 GB. Deze machine (30 GB RAM) heeft
  daarom een eenmalige host-fix nodig (zie hieronder).

### Eenmalige host-fix: extra swap + systemd-oomd uit

Zonder deze fix wordt de build tijdens de Soong-analyse OOM-gekilled:

```bash
sudo fallocate -l 32G /swapfile2
sudo chmod 600 /swapfile2
sudo mkswap /swapfile2
sudo swapon /swapfile2

sudo systemctl stop systemd-oomd.service systemd-oomd.socket
sudo systemctl mask systemd-oomd.service systemd-oomd.socket
```

> `systemctl disable --now systemd-oomd` alleen is **niet** genoeg — de socket
> start de service opnieuw via socket-activatie. Je moet ook de socket stoppen/masken.
>
> Terugdraaien: `sudo swapoff /swapfile2 && sudo rm /swapfile2` en
> `sudo systemctl unmask systemd-oomd.service systemd-oomd.socket && sudo systemctl enable --now systemd-oomd`.

---

## Bestanden

| Bestand | Doel |
|---|---|
| `Dockerfile` | Bouwt de build-image (Ubuntu 24.04 + AOSP-deps + JDK 17 + `repo`) |
| `build.sh` | Sync + build (de "volgende build") |
| `check-updates.sh` | Controleert of er nieuwe upstream-commits zijn |
| `release.sh` | Publiceert een nieuwe build als OTA (SourceForge-upload + JSON) |
| `setup-keys.sh` | Kopieert release-signing keys naar de build-tree (release-keys) |
| `local_manifests/garnet.xml` | Versied copy van de local_manifest (device tree wijst naar eigen fork) |
| `ota/garnet.json` | OTA-metadata die de Updater-app op het toestel uitleest |
| `src/` | De volledige AOSP/EvolutionX-bron |
| `src/.repo/local_manifests/garnet.xml` | garnet device tree + dependencies |
| `ccache/` | Persistente ccache (versnelt volgende builds) |

---

## Een nieuwe build maken

```bash
./build.sh
```

Dit start (indien nodig) de container, synct de bron (`repo sync`) en draait
`m evolution -j16`. De output wordt tegelijk op het scherm getoond en naar
`src/build-<tijdstip>.log` weggeschreven. Aan het einde vraagt het script of je de
release direct wilt publiceren (SourceForge-upload + OTA-JSON).

### Handmatig (zonder script)

```bash
docker exec garnet-builder bash -c '
  cd /src
  export USE_CCACHE=1 CCACHE_DIR=/ccache CCACHE_EXEC=/usr/bin/ccache
  repo sync -c -j16 --force-sync --no-clone-bundle --no-tags
  source build/envsetup.sh
  lunch lineage_garnet-userdebug
  ccache -M 50G
  m evolution -j16
'
```

> Gebruik `-j16` (geen `-j22`) om geheugenpieken te beperken op 30 GB RAM.
> De eerste build duurt 3-4 uur; een volgende build is veel sneller dankzij ccache
> en de al gebouwde `out/`.

---

## Checken of een nieuwe build zinvol is

```bash
./check-updates.sh
```

Het script haalt upstream op (netwerk-only, wijzigt de working tree **niet**) en
toont per project hoeveel nieuwe commits er zijn. Geen uitvoer = bron is up-to-date,
geen nieuwe build nodig.

---

## Flashen op je toestel

> ⚠️ Flashen **wist al je data**, kan de garantie beïnvloeden en kan bij fouten je
> toestel **bricken**. Controleer altijd de exacte stappen op de officiële
> EvolutionX-pagina voor garnet: <https://evolution-x.org/device/garnet>.

Algemene flow:

1. **Bootloader unlocken** (vereist; via Xiaomi Mi Unlock-tool).
2. Toestel in fastboot-modus.
3. Boot-images flashen:
   ```bash
   fastboot flash boot boot.img
   fastboot flash vendor_boot vendor_boot.img
   fastboot flash dtbo dtbo.img
   ```
4. Naar recovery: `fastboot reboot recovery`.
5. In recovery: **Format data / factory reset**.
6. ROM sideloaden:
   ```bash
   adb sideload EvolutionX-16.0-<datum>-garnet-11.11-Unofficial.zip
   ```

De benodigde images (`boot.img`, `vendor_boot.img`, `dtbo.img`) staan naast de zip
in `src/out/target/product/garnet/`.

---

## OTA-updates

De ROM ondersteunt OTA via de EvolutionX-**Updater**-app. Die leest een JSON uit
en downloadt de update; de JSON wordt in deze repo gehost, de ROM-zip op SourceForge.

### Hoe het werkt

1. De Updater-app vraagt
   `https://raw.githubusercontent.com/Hayqe/garnet-evolutionx/main/ota/garnet.json` op.
   Die URL wordt ingesteld via de RRO-overlay `UpdaterOverlayGarnet` in de
   (geforkte) device tree.
2. De JSON bevat download-URL, md5, grootte en build-timestamp van de nieuwste
   build. Alleen een update met een `timestamp` *nieuwer* dan de geïnstalleerde
   build wordt getoond.
3. De app downloadt de zip van SourceForge en past hem toe via `update_engine`
   (virtuele A/B — geen dataverlies).

### Een update uitbrengen

```bash
PUBLISH=1 ./release.sh
```

Dit uploadt de zip naar SourceForge (`garnet-evolutionx`), schrijft `ota/garnet.json`
en pusht de JSON naar GitHub. Enkele minuten later zien toestellen de update in de
Updater-app. (`SF_USER`/`SF_PROJECT` zijn standaard al `hayqe`/`garnet-evolutionx`.)

### Vereisten (eenmalig)

- **SourceForge-project** `garnet-evolutionx` met een SSH-key op je account
  (`SF_USER` / `SF_PROJECT`).
- **GitHub-repo's** `garnet-evolutionx` (deze repo) en een fork van
  `device_xiaomi_garnet` met de `UpdaterOverlayGarnet`-overlay.
- **Signing-keys** in `~/.android-certs/` (eigen release key, zie hieronder).

### Signing

Voor OTA tussen builds is een *consistente* signeerkey nodig. Je bouwt met je eigen
release key (niet de publieke testkeys) door:

```bash
./setup-keys.sh
```

Dit kopieert de keys van `~/.android-certs/` naar `src/vendor/evolution-priv/keys/`
en schrijft `keys.mk`. EvolutionX pikt die automatisch op, waardoor de build met
`release-keys` wordt getekend (in plaats van `test-keys`). Daarnaast wordt een
AVB-key (RSA-4096, `avb.pem`) gegenereerd en door de device-tree fork gebruikt voor
Verified Boot.

> ⚠️ De private keys in `src/vendor/evolution-priv/keys/` worden **niet** gecommit
> (valt onder `src/` in `.gitignore`). Bewaar `~/.android-certs/` veilig — raak je de
> key kwijt, dan moet je opnieuw clean flashen.

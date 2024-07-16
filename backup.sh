#!/usr/bin/env bash

set -eu

if [ "$(id --user)" -ne 0 ]; then
	echo "this script must be run as root"
	exit 1
fi

PARENT="$(pwd)"
DB_DIR="${PARENT}/db"
PRESETS_DIR="${PARENT}/airootfs/usr/local/share/presets"
CACHE_DIR="${PARENT}/airootfs/usr/local/share/repo/pkg"
AUR_DIR="${PARENT}/aur"
LOG_FILE="${PARENT}/pacman"
MAIN_PACKS="${PARENT}/packs-list"
OUTPUT=releng.tar

mkdir --parents --verbose "$DB_DIR"
mv --verbose "${LOG_FILE}.log" "${LOG_FILE}_$(date +%Y-%m-%dT%H%M%S).log" 2> /dev/null || :

# all presets except aur
cat "${PRESETS_DIR}/base" "${PRESETS_DIR}/tools" "${PRESETS_DIR}/dev" "${PRESETS_DIR}/vm" "${PRESETS_DIR}/misc" > "$MAIN_PACKS"

# aur dependencies (aur packages MUST be installed to local system for this to work)
pacman --query --info - 2> /dev/null < "${PRESETS_DIR}/aur" \
	| grep --extended-regexp "Depends On\s+:\s+.+" \
	| xargs --max-args=1 | sort | uniq \
	| grep --invert-match --extended-regexp "^Depends$|^On$|^None$|oracle|^:$" >> "$MAIN_PACKS"

# first, clean AUR_DIR, since it is manually managed (package pacman-contrib is needed)
paccache --cachedir "$AUR_DIR" --remove --keep 1

# download and "install" packages; saves them in CACHE_DIR and creates/updates DB_DIR
pacman --sync --refresh --sysupgrade --needed --dbonly --logfile "${LOG_FILE}.log" --dbpath "$DB_DIR" --cachedir "$CACHE_DIR" - < "$MAIN_PACKS"
# install aur packages found in AUR_DIR and then move them to CACHE_DIR
# to add new aur package, just copy it to AUR_DIR; the next time this script is run it will be handled
if [ -n "$(find "$AUR_DIR" -mindepth 1 -maxdepth 1 2> /dev/null)" ]; then
	pacman --upgrade "${AUR_DIR}"/*.tar.zst --needed --dbonly --logfile "${LOG_FILE}.log" --dbpath "$DB_DIR"
	mv --verbose "${AUR_DIR}"/*.tar.zst "${CACHE_DIR}/"
fi

rm --verbose --force "$OUTPUT" "$MAIN_PACKS" "$CACHE_DIR"/pkg.db* "$CACHE_DIR"/pkg.files*

# keep only packages present in DB_DIR
pacman --sync --clean --verbose --logfile "${LOG_FILE}.log" --cachedir "$CACHE_DIR" --dbpath "$DB_DIR" --noconfirm

repo-add --quiet "${CACHE_DIR}/pkg.db.tar.gz" $(find $CACHE_DIR/*.pkg.tar.* -type f -not -path "*.sig" -print0 | xargs --null)

# back everything up
tar --create --verbose --file "$OUTPUT" --exclude "*.log" .

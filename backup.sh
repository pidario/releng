#!/bin/sh

set -eu

if [ "$(id --user)" -ne 0 ]; then
	echo "this script must be run as root"
	exit 1
fi

NODB=/tmp/nodb
PRESETS_DIR=./airootfs/usr/local/share/presets
CACHE_DIR=./airootfs/usr/local/share/repo/pkg
AUR_DIR=./airootfs/usr/local/share/repo/aur
ALL_PACKS=packs-list

rm --force --recursive backup.tar "$NODB"
mkdir --parents $NODB

cat $PRESETS_DIR/base $PRESETS_DIR/tools $PRESETS_DIR/dev $PRESETS_DIR/vm $PRESETS_DIR/misc > "$ALL_PACKS"

# aur dependencies
pacman --query --info - 2> /dev/null < $PRESETS_DIR/aur \
	| grep --extended-regexp "Depends On\s+:\s+.+" \
	| xargs --max-args=1 | sort | uniq \
	| grep --invert-match --extended-regexp "^Depends$|^On$|^None$|oracle|^:$" >> "$ALL_PACKS"

# this is useful to detect dependencies
#while IFS= read -r p; do
#	echo "$p" >> "test_deps"
#	pacman --sync --logfile /dev/null --noconfirm --dbpath $NODB --print "$p" >> "test_deps"
#done < "$ALL_PACKS"
#rm "$ALL_PACKS"
#exit 0

pacman --sync --refresh --downloadonly --logfile /dev/null --dbpath $NODB --cachedir $CACHE_DIR - < "$ALL_PACKS"
rm "$ALL_PACKS"

# keep only latest version of each package in cache (package pacman-contrib)
paccache --cachedir $CACHE_DIR --cachedir $AUR_DIR --remove --keep 1

TODAY="$(date +%Y-%m-%d)"
# add latest file to custom sync databases:
repo-add --quiet $CACHE_DIR/pkg.db.tar.gz $(find $CACHE_DIR/*.pkg.tar.* -type f -not -path "*.sig" -newerct "$TODAY" -print0 | xargs --null)
#repo-add --quiet $AUR_DIR/aur.db.tar.gz $(find $AUR_DIR/*.pkg.tar.* -type f -not -path "*.sig" -newerct "$TODAY" -print0 | xargs --null)

# to instead add every package (takes a long time):
#repo-add --quiet "$CACHE_DIR"/pkg.db.tar.gz $(find $CACHE_DIR/*.pkg.tar.* -type f -not -path "*.sig" -print0 | xargs --null)
repo-add --quiet "$AUR_DIR"/aur.db.tar.gz $(find $AUR_DIR/*.pkg.tar.* -type f -not -path "*.sig" -print0 | xargs --null)

# back everything up
tar --create --verbose --file backup.tar .

# to skip packages:
# tar --exclude airootfs/usr/local/share/repo --create --verbose --file backup-mini.tar .

## to remove PACKAGE from the custom database:
# repo-remove "$CACHE_DIR"/pkg.db.tar.gz "$PACKAGE"
# rm "$CACHE_DIR"/$PACKAGE*

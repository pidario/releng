#!/bin/sh

PACKS=$(find ./airootfs/usr/local/share/repo/pkg/*.pkg.tar.* -type f -not -path "*.sig")

for f in $PACKS; do
	if [ ! -f "$f".sig ]; then
		echo "$f"
		rm --force "$f"
	fi
done

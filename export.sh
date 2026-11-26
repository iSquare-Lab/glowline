#!/bin/sh
# Imports the Godot project, runs the tests and exports it to web/ (the folder that is served, see strux.json).
# GODOT points at a Godot 4.7.2 binary with the 4.7.2 web export templates installed.
set -eu
GODOT="${GODOT:-godot}"
cd "$(dirname "$0")"
"$GODOT" --headless --path project --import
"$GODOT" --headless --path project --script res://tests/run_tests.gd
# Export into a fresh folder and swap it in only when the export worked, so a failed export never leaves
# web/ empty or half written.
tmp=.web-export
rm -rf "$tmp"
mkdir "$tmp"
trap 'rm -rf "$tmp"' EXIT
"$GODOT" --headless --path project --export-release "Web" "../$tmp/index.html"
for file in index.html index.js index.wasm index.pck; do
	if [ ! -s "$tmp/$file" ]; then
		echo "export.sh: the export did not write $file; web/ is unchanged" >&2
		exit 1
	fi
done
# The licences travel with the build: the game's own and Godot's third-party notices.
cp LICENSE THIRD_PARTY_NOTICES.txt "$tmp/"
rm -rf web
mv "$tmp" web
ls -l web

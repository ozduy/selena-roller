#!/bin/sh
# Copies the web game from the repository root into the app as web/ at build time.
# Xcode runs this as a build phase (see project.yml), so the game files live only once in git,
# the same files GitHub Pages serves.
set -eu

src="${SRCROOT}/.."
dest="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/web"

rm -rf "$dest"
mkdir -p "$dest"

cp "$src/index.html" "$src/three.min.js" "$src/manifest.webmanifest" "$dest/"
cp "$src"/icon-*.png "$dest/"
cp -R "$src/fonts" "$dest/fonts"

# Stop the build if index.html links to a local file that was not copied (a new file needs adding above).
refs=$(grep -oE '(src|href)="[^"#][^"]*"' "$dest/index.html" | sed -E 's/^(src|href)="//; s/"$//' | sort -u || true)
missing=0
while IFS= read -r ref; do
  case "$ref" in
    "" | http:* | https:* | data:* | mailto:* | tel:* | javascript:*) continue ;;
  esac
  ref="${ref%%\?*}"
  if [ ! -e "$dest/$ref" ]; then
    echo "error: index.html refers to $ref, which bundle-web.sh does not copy into the app"
    missing=1
  fi
done <<EOF
$refs
EOF
if [ "$missing" -ne 0 ]; then
  exit 1
fi

echo "Copied the web game into $dest"

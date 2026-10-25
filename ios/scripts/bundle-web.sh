#!/bin/sh
# Copies the web game from the repository root into the app as web/ at build time.
# Xcode runs this as a build phase (see project.yml), so the game files live only once in git,
# the same files GitHub Pages serves.
set -eu

src="${SRCROOT}/.."
dest="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/web"

rm -rf "$dest"
mkdir -p "$dest"

cp "$src/index.html" "$src/three.min.js" "$src/manifest.webmanifest" "$src/THIRD-PARTY-NOTICES.txt" "$dest/"
cp "$src"/icon-*.png "$dest/"
cp -R "$src/fonts" "$dest/fonts"

# The app never uses the internet (privacy policy, App Privacy answers, review notes), so stop the build if the
# game loads a script, stylesheet, font, picture or other file from another site. Ordinary links
# (<a href="https://...">) are fine: the app opens them in Safari.
remote=$(grep -oE '<[A-Za-z][A-Za-z0-9-]*[^>]*[[:space:]](src|href|srcset|poster|data)="(https?:)?//[^"]*"' "$dest/index.html" \
  | grep -vE '^<a[[:space:]]' || true)
css_pattern='(url\(|@import)[[:space:]]*(url\()?[[:space:]]*["'"'"']?(https?:)?//'
remote_css=$(grep -ohE "$css_pattern" "$dest/index.html" "$dest"/fonts/*.css || true)
if [ -n "$remote$remote_css" ]; then
  echo "error: the game loads files from the internet, but the app must contain everything it uses:"
  printf '%s\n%s\n' "$remote" "$remote_css" | sed -e '/^$/d' -e 's/^/  /'
  exit 1
fi

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

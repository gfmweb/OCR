#!/usr/bin/env bash
set -euo pipefail

PREFIX=/opt/nacta-passport
STAGING=/tmp/nacta-deb
SRC=/src
MODELS=/models
OUT=/out
WORK=/tmp/nacta-src

mkdir -p "${HOME:-/tmp/builder-home}"

cd /
rm -rf "$WORK" "$STAGING"
mkdir -p "$WORK" "$STAGING$PREFIX" "$OUT"

rsync -a \
  --exclude '.git/' \
  --exclude 'build/' \
  --exclude '.dart_tool/' \
  --exclude 'dist/' \
  --exclude 'evaluation/' \
  --exclude 'python_service/.venv/' \
  --exclude 'python_service/models/' \
  --exclude 'python_service/.session_token' \
  --exclude 'python_service/.env' \
  --exclude '**/__pycache__/' \
  "$SRC"/ "$WORK"/

cd "$WORK"
git config --global --add safe.directory /opt/flutter || true
flutter config --no-analytics --enable-linux-desktop >/dev/null
flutter pub get
flutter build linux --release

cd "$WORK/python_service"
uv python install 3.12
if ! uv venv --python 3.12 --relocatable .venv; then
  uv venv --python 3.12 .venv
fi
uv sync --python 3.12 --no-dev

BUNDLE="$WORK/build/linux/x64/release/bundle"
if [[ ! -x "$BUNDLE/ru_passport" ]]; then
  echo "Flutter linux bundle is missing" >&2
  exit 1
fi
rsync -a "$BUNDLE"/ "$STAGING$PREFIX"/

mkdir -p "$STAGING$PREFIX/python_service"
rsync -a \
  --exclude '.venv/' \
  --exclude 'models/' \
  --exclude 'tests/' \
  --exclude '.session_token' \
  --exclude '.env' \
  --exclude '**/__pycache__/' \
  "$WORK/python_service"/ "$STAGING$PREFIX/python_service"/
rsync -a "$WORK/python_service/.venv"/ "$STAGING$PREFIX/python_service/.venv"/
mkdir -p "$STAGING$PREFIX/python_service/models"
rsync -a "$MODELS"/ "$STAGING$PREFIX/python_service/models"/

VENV_PY="$STAGING$PREFIX/python_service/.venv/bin/python"
REAL_PY="$(readlink -f "$VENV_PY")"
PY_ROOT="$(dirname "$(dirname "$REAL_PY")")"
mkdir -p "$STAGING$PREFIX/python"
rm -rf "$STAGING$PREFIX/python/runtime"
cp -a "$PY_ROOT" "$STAGING$PREFIX/python/runtime"

RUNTIME_BIN="$STAGING$PREFIX/python/runtime/bin"
if [[ -x "$RUNTIME_BIN/python3.12" ]]; then
  RUNTIME_NAME=python3.12
elif [[ -x "$RUNTIME_BIN/python3" ]]; then
  RUNTIME_NAME=python3
else
  echo "Bundled CPython 3.12 is missing" >&2
  exit 1
fi
ln -sfn "/opt/nacta-passport/python/runtime/bin/${RUNTIME_NAME}" "$STAGING$PREFIX/python_service/.venv/bin/python"
ln -sfn python "$STAGING$PREFIX/python_service/.venv/bin/python3"

cat > "$STAGING$PREFIX/python_service/.venv/pyvenv.cfg" <<EOF
home = /opt/nacta-passport/python/runtime/bin
include-system-site-packages = false
executable = /opt/nacta-passport/python/runtime/bin/${RUNTIME_NAME}
EOF

while IFS= read -r -d '' file; do
  if head -n 1 "$file" | grep -q '^#!.*python'; then
    sed -i '1s|.*|#!/opt/nacta-passport/python_service/.venv/bin/python|' "$file"
  fi
done < <(find "$STAGING$PREFIX/python_service/.venv/bin" -type f -print0)

VERSION="$(grep -E '^version:' "$SRC/pubspec.yaml" | head -n 1 | awk '{print $2}' | cut -d+ -f1)"
install -D -m 0755 "$SRC/packaging/linux/nacta-passport.sh" "$STAGING$PREFIX/bin/nacta-passport"
mkdir -p "$STAGING/usr/bin"
ln -sfn /opt/nacta-passport/bin/nacta-passport "$STAGING/usr/bin/nacta-passport"
install -D -m 0644 "$SRC/packaging/linux/nacta-passport.desktop" \
  "$STAGING/usr/share/applications/nacta-passport.desktop"
install -D -m 0644 "$SRC/assets/branding/nacta_icon.png" \
  "$STAGING/usr/share/icons/hicolor/256x256/apps/nacta-passport.png"

SIZE="$(du -sk "$STAGING/opt" "$STAGING/usr" | awk '{s+=$1} END {print s}')"
mkdir -p "$STAGING/DEBIAN"
sed -e "s/@VERSION@/${VERSION}/" "$SRC/packaging/linux/debian/control.in" \
  | awk -v size="$SIZE" 'BEGIN{added=0} /^Architecture:/{print; print "Installed-Size: " size; added=1; next} {print}' \
  > "$STAGING/DEBIAN/control"
install -m 0755 "$SRC/packaging/linux/debian/postinst" "$STAGING/DEBIAN/postinst"
install -m 0755 "$SRC/packaging/linux/debian/postrm" "$STAGING/DEBIAN/postrm"

# Drop leftover write-only session files from the build venv.
rm -f "$STAGING$PREFIX/python_service/.session_token"

DEB="$OUT/nacta-passport_${VERSION}_amd64.deb"
echo "packing $DEB (this may take several minutes)"
dpkg-deb -Zgzip --build --root-owner-group "$STAGING" "$DEB"
echo "built $DEB"
ls -lh "$DEB"

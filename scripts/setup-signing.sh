#!/usr/bin/env bash
# One-time: creates a self-signed code-signing certificate "Shotty Local Signing" in your
# login keychain. Builds signed with it keep the same identity, so macOS remembers
# Shotty's Accessibility, Screen Recording and folder permissions across rebuilds and updates.
#
# This is not an Apple Developer ID: Gatekeeper still treats downloads as unidentified.
# For notarized releases see docs/RELEASING.md.
set -euo pipefail

NAME="${SHOTTY_CERT_NAME:-Shotty Local Signing}"
KEYCHAIN="${SHOTTY_KEYCHAIN:-$HOME/Library/Keychains/login.keychain-db}"

if security find-certificate -c "$NAME" "$KEYCHAIN" >/dev/null 2>&1; then
  echo "\"$NAME\" already exists in your login keychain. Nothing to do."
  exit 0
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/cert.cnf" <<CNF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $NAME
[ext]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
CNF

openssl req -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes \
  -keyout "$TMP/key.pem" -out "$TMP/cert.pem" -config "$TMP/cert.cnf" 2>/dev/null
PASS=$(openssl rand -hex 16)
openssl pkcs12 -export -legacy -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
  -name "$NAME" -out "$TMP/cert.p12" -passout "pass:$PASS" 2>/dev/null \
|| openssl pkcs12 -export -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
  -name "$NAME" -out "$TMP/cert.p12" -passout "pass:$PASS"

# -T lets codesign use the key without a keychain prompt each build.
security import "$TMP/cert.p12" -k "$KEYCHAIN" -P "$PASS" -T /usr/bin/codesign >/dev/null

echo "Created \"$NAME\" in $(basename "$KEYCHAIN")."
echo "Next: scripts/build-app.sh (it picks the certificate up automatically), then scripts/install.sh"

#!/bin/sh
# One-shot self-signed cert generator for the testnet.
# Produces one PEM per server with CN matching the hostname.
# Skips existing files so subsequent `up` runs are idempotent.
set -eu
cd "$(dirname "$0")"

# alpine:3.20 does not have openssl by default — install it on first run.
if ! command -v openssl >/dev/null 2>&1; then
    apk add --no-cache openssl >/dev/null
fi

for cn in hub leaf4 leaf6 services; do
    pem="${cn}.pem"
    if [ -s "${pem}" ]; then
        continue
    fi
    openssl req -x509 -newkey rsa:2048 -nodes -days 365 \
        -subj "/CN=${cn}.azzurra.chat" \
        -keyout "${cn}.key" -out "${pem}" >/dev/null 2>&1
    # Concatenate key into the .pem so ircd can load it in one file.
    cat "${cn}.key" >> "${pem}"
    rm -f "${cn}.key"
    echo "generated ${pem}"
done

# Network-wide cloak key. Must be identical on every bahamut instance —
# crypt_userhost.c seeds the +x host hash with the file's bytes, so
# divergent keys mean the same user shows different cloaked hosts on
# hub vs leaf. Generate once here, mount read-only into every bahamut
# container, entrypoint copies into DPATH/ircd.cloak.
if [ ! -s ircd.cloak ]; then
    head -c 128 /dev/urandom | od -An -tx1 | tr -d ' \n' > ircd.cloak
    echo "generated ircd.cloak"
fi

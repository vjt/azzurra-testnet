#!/bin/sh
# Role-aware bahamut entrypoint.
# Expands the correct conf template per SERVER_ROLE and execs ircd in foreground.
set -eu

: "${SERVER_ROLE:?SERVER_ROLE is required (hub|leaf4|leaf6)}"
: "${SERVER_NAME:?}"
: "${LISTEN_PORT:?}"
: "${LISTEN_SSL_PORT:?}"
: "${OPER_NICK:?}"
: "${OPER_PASS:?}"

case "${SERVER_ROLE}" in
    hub)
        : "${SERVICES_PASSWORD:?}"
        : "${LEAF_PASSWORD:?}"
        : "${LINK_PORT_V4:?}"
        : "${LINK_PORT_V6:?}"
        : "${SERVICES_IP:?}"
        : "${LEAF4_IP:?}"
        : "${LEAF6_IP:?}"
        tmpl=/etc/bahamut/conf.hub.tmpl
        ;;
    leaf4|leaf6)
        : "${HUB:?}"
        : "${HUB_PORT:?}"
        : "${LEAF_PASSWORD:?}"
        tmpl="/etc/bahamut/conf.${SERVER_ROLE}.tmpl"
        ;;
    *)
        printf 'unknown SERVER_ROLE=%s\n' "${SERVER_ROLE}" >&2
        exit 2
        ;;
esac

# Hash the oper password with the system crypt(3) — bahamut O-lines expect a
# crypted password so leaking the running conf does not leak the plaintext.
# Uses a random 2-char DES salt; good enough for a throwaway testnet.
OPER_PASS_HASH="$(mkpasswd --method=des "${OPER_PASS}")"
export OPER_PASS_HASH

# Generate conf from template (limit envsubst to known vars so `$foo`
# strings inside conf comments are left alone).
VARS='$SERVER_NAME $SERVER_DESC $OPER_NICK $OPER_PASS_HASH'
VARS="$VARS \$LISTEN_PORT \$LISTEN_SSL_PORT"
VARS="$VARS \$LINK_PORT_V4 \$LINK_PORT_V6"
VARS="$VARS \$HUB \$HUB_PORT \$HUB_IP"
VARS="$VARS \$SERVICES_IP \$LEAF4_IP \$LEAF6_IP"
VARS="$VARS \$SERVICES_PASSWORD \$LEAF_PASSWORD"

envsubst "${VARS}" < "${tmpl}" > /etc/bahamut/bahamut.conf

# Cloak key — bahamut-azzurra needs a >=64-byte key at DPATH/ircd.cloak
# (see include/config.h MIN_CLOAK_KEY_LEN/CKPATH). Testnet-random per boot.
if [ ! -s /var/lib/bahamut/ircd.cloak ]; then
    head -c 128 /dev/urandom | od -An -tx1 | tr -d ' \n' \
        > /var/lib/bahamut/ircd.cloak
fi

# SSL — bahamut-azzurra expects ircd.crt + ircd.key in DPATH
# (include/config.h: IRCDSSL_CPATH / IRCDSSL_KPATH). Our cert-init produces
# one combined <role>.pem per host (cert || key); openssl's
# use_certificate_chain_file + use_PrivateKey_file both accept combined PEM,
# so symlink the same file to both expected names.
case "${SERVER_ROLE}" in
    hub)   pem=/etc/bahamut/certs/hub.pem    ;;
    leaf4) pem=/etc/bahamut/certs/leaf4.pem  ;;
    leaf6) pem=/etc/bahamut/certs/leaf6.pem  ;;
esac
if [ -s "${pem}" ]; then
    ln -sf "${pem}" /var/lib/bahamut/ircd.crt
    ln -sf "${pem}" /var/lib/bahamut/ircd.key
fi

# Dump the conf to stderr at startup (modulo OPER hash) for debugging.
# Real tokens stay out of stdout anyway — this is a testnet image.
printf '=== %s bahamut.conf ===\n' "${SERVER_ROLE}" >&2
sed -e 's/O:\(.*\):[^:]*:\(.*\)/O:\1:<hashed>:\2/' /etc/bahamut/bahamut.conf >&2
printf '=== end bahamut.conf ===\n' >&2

exec /usr/local/sbin/ircd -t -s -d /var/lib/bahamut -f /etc/bahamut/bahamut.conf

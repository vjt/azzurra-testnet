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
VARS="$VARS \$HUB \$HUB_PORT"
VARS="$VARS \$SERVICES_PASSWORD \$LEAF_PASSWORD"

envsubst "${VARS}" < "${tmpl}" > /etc/bahamut/bahamut.conf

# Dump the conf to stderr at startup (modulo OPER hash) for debugging.
# Real tokens stay out of stdout anyway — this is a testnet image.
printf '=== %s bahamut.conf ===\n' "${SERVER_ROLE}" >&2
sed -e 's/O:\(.*\):[^:]*:\(.*\)/O:\1:<hashed>:\2/' /etc/bahamut/bahamut.conf >&2
printf '=== end bahamut.conf ===\n' >&2

cd /var/lib/bahamut
exec /usr/local/sbin/ircd -F -f /etc/bahamut/bahamut.conf

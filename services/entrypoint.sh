#!/bin/sh
# Services entrypoint.
# Expands conf.tmpl into /opt/azzurra/services/services.conf and execs the
# binary from /opt/azzurra/services/ (startup cwd), so that main.c:200
# chdir(SERVICES_DIR="./data") resolves under PREFIX and ../services.conf
# (inc/config.h:50) + ../lang.conf (src/lang.c:139) open correctly.
set -eu

: "${SERVICES_NAME:?}"
: "${SERVICES_DESC:?}"
: "${HUB:?}"
: "${HUB_PORT:?}"
: "${SERVICES_PASSWORD:?}"
: "${SERVICES_MASTER:?}"

PREFIX=/opt/azzurra/services

envsubst '$SERVICES_NAME $SERVICES_DESC $HUB $HUB_PORT $SERVICES_PASSWORD $SERVICES_MASTER' \
    < "${PREFIX}/services.conf.tmpl" > "${PREFIX}/services.conf"

# lang.conf is not shipped in the repo — doc/lang.conf.example is the
# canonical form (4 ADDLANG lines for the 4 compiled .clng files). Write it
# here if missing so lang_load_conf() finds it at ../lang.conf (src/lang.c:139).
if [ ! -f "${PREFIX}/lang.conf" ]; then
    cat > "${PREFIX}/lang.conf" <<'EOF'
ADDLANG IT START HOLD
ADDLANG US START HOLD
ADDLANG ES START HOLD
ADDLANG FR START HOLD
EOF
fi

# crypt.key — symmetric key for hidehost (+x) encryption (crypt_userhost.c
# opens "../crypt.key" from the data/ cwd, requires >64 bytes; absent or
# short → fatal at startup). Generate a random 128-byte hex key on first
# boot, throwaway / testnet only.
if [ ! -f "${PREFIX}/crypt.key" ]; then
    head -c 64 /dev/urandom | od -An -tx1 | tr -d ' \n' > "${PREFIX}/crypt.key"
fi

cd "${PREFIX}"
# -F keeps services attached to stdio so docker sees the main process
# (azzurra/services main.c otherwise fork()s and the parent exits → container
# dies). Depends on azzurra/services#12.
exec ./bin/services -F

#!/bin/sh
# Services entrypoint.
# Expands conf.tmpl into /opt/azzurra/services/services.conf and execs the
# binary from its expected bin/ dir so that main.c's chdir(dirname(argv[0]))
# lands in bin/ and the "../services.conf" + "../lang.conf" opens resolve
# under /opt/azzurra/services/.
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

# lang.conf ships in /src/lang/lang.conf during build but langcomp uses the
# built .clng files from /opt/azzurra/services/lang/. Make sure services can
# find the canonical lang.conf by pointing at the lang/ dir's config.
if [ ! -f "${PREFIX}/lang.conf" ]; then
    if [ -f "${PREFIX}/lang/lang.conf" ]; then
        ln -sf lang/lang.conf "${PREFIX}/lang.conf"
    fi
fi

# Services has no CLI args — it chdirs relative to argv[0] and reads
# ../services.conf from there.
cd "${PREFIX}/bin"
exec ./services

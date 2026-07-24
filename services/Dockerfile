# syntax=docker/dockerfile:1.6
FROM debian:trixie AS build
ARG SERVICES_REF=master
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential libc6-dev python3 ca-certificates git \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /src
# Support branches, tags, and arbitrary refs (incl. refs/pull/N/head + full SHAs).
RUN git init -q \
 && git remote add origin https://github.com/azzurra/services.git \
 && git fetch --depth=1 origin "${SERVICES_REF}" \
 && git checkout -q FETCH_HEAD
# Precompile lang files — langcomp.py regenerates svc*.clng from *.lang sources.
RUN ./configure && cd lang && python3 langcomp.py && cd .. && make

FROM debian:trixie-slim
# msmtp + msmtp-mta (GH #349): services shells out via
# system("<SENDMAIL> -f <RETURN> -t < authnick.txt") to email the AUTH
# code (nickserv.c do_register). msmtp-mta symlinks /usr/sbin/sendmail →
# msmtp; /etc/msmtprc relays to the mailpit sink. Only exercised when the
# grappa e2e compose sets SVC_EMAIL=1 (default off — the standalone
# testnet never invokes it).
RUN apt-get update && apt-get install -y --no-install-recommends \
    libc6 gettext-base ca-certificates msmtp msmtp-mta \
 && rm -rf /var/lib/apt/lists/*
# Services expects layout: <prefix>/bin/services with conf + data one level up.
#   main.c chdirs to dirname(argv[0]); conf.c opens "../services.conf";
#   lang.c opens "../lang.conf"; data files live under ../data/.
# We mirror that at /opt/azzurra/services/.
RUN useradd -r -s /usr/sbin/nologin -d /var/lib/services services \
 && mkdir -p /opt/azzurra/services/bin /opt/azzurra/services/lang /var/lib/services \
 && chown -R services: /opt/azzurra /var/lib/services
COPY --from=build /src/src/services /opt/azzurra/services/bin/services
COPY --from=build /src/lang /opt/azzurra/services/lang
COPY --from=build /src/run/data /opt/azzurra/services/data
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY conf.tmpl /opt/azzurra/services/services.conf.tmpl
# /etc/msmtprc (GH #349) — testnet-only relay to the mailpit sink. msmtp
# refuses a config WRITABLE by others, not a readable one, so 0644 root
# is fine (no secrets — auth off). Unused unless SVC_EMAIL=1.
COPY msmtprc /etc/msmtprc
RUN chmod +x /usr/local/bin/entrypoint.sh \
 && chmod 0644 /etc/msmtprc \
 && chown -R services: /opt/azzurra
USER services
WORKDIR /opt/azzurra/services
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

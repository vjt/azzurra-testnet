# syntax=docker/dockerfile:1.6
FROM debian:trixie AS build
ARG BAHAMUT_REF=master
RUN apt-get update && apt-get install -y --no-install-recommends \
    autoconf build-essential libssl-dev zlib1g-dev libcrypt-dev \
    ca-certificates git file \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /src
# Support branches, tags, and arbitrary refs (incl. refs/pull/N/head + full SHAs)
# by initialising empty repo + shallow-fetching the requested ref.
RUN git init -q \
 && git remote add origin https://github.com/azzurra/bahamut.git \
 && git fetch --depth=1 origin "${BAHAMUT_REF}" \
 && git checkout -q FETCH_HEAD
COPY options.h_hub include/options.h
# Patch config.h to undef NO_CHANOPS_WHEN_SPLIT — the include order in
# upstream is `config.h` includes `options.h` BEFORE its own
# `#define NO_CHANOPS_WHEN_SPLIT` at line 594, so an `#undef` placed
# in options.h is silently overridden moments later by config.h. The
# CFLAGS=-U route doesn't apply either: the source is gated on
# `#ifdef`, so `-D=0` would still satisfy the ifdef. Sed-deleting the
# define line in config.h is the only edit that takes effect through
# the existing include order, and it's surgical (one line, one file)
# so it stays trivially auditable. Rationale for disabling:
# infra/bahamut/options.h_hub's NO_CHANOPS_WHEN_SPLIT block.
RUN sed -i '/^#define NO_CHANOPS_WHEN_SPLIT$/d' include/config.h
RUN autoconf && ./configure && make

FROM debian:trixie-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
    libssl3 zlib1g libcrypt1 ca-certificates gettext-base whois \
 && rm -rf /var/lib/apt/lists/*
COPY --from=build /src/src/ircd /usr/local/sbin/ircd
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY conf.hub.tmpl conf.leaf4.tmpl conf.leaf6.tmpl /etc/bahamut/
RUN chmod +x /usr/local/bin/entrypoint.sh \
 && useradd -r -s /usr/sbin/nologin -d /var/lib/bahamut ircd \
 && mkdir -p /var/lib/bahamut /etc/bahamut/certs \
 && chown -R ircd: /var/lib/bahamut /etc/bahamut
USER ircd
WORKDIR /var/lib/bahamut
EXPOSE 6667 6697 7000 7001
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# syntax=docker/dockerfile:1.6
FROM debian:trixie AS build
ARG BAHAMUT_REF=master
RUN apt-get update && apt-get install -y --no-install-recommends \
    autoconf build-essential libssl-dev zlib1g-dev libcrypt-dev \
    ca-certificates git file \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /src
RUN git clone --depth=1 --branch="${BAHAMUT_REF}" https://github.com/azzurra/bahamut.git .
COPY options.h_hub include/options.h
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

# syntax=docker/dockerfile:1.6
FROM debian:trixie AS build
ARG SERVICES_REF=master
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential libc6-dev python3 ca-certificates git \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /src
RUN git clone --depth=1 --branch="${SERVICES_REF}" https://github.com/azzurra/services.git .
# Precompile lang files — langcomp.py regenerates svc*.clng from *.lang sources.
RUN ./configure && cd lang && python3 langcomp.py && cd .. && make

FROM debian:trixie-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
    libc6 gettext-base ca-certificates \
 && rm -rf /var/lib/apt/lists/*
# Services expects layout: <prefix>/bin/services with conf + data one level up.
#   main.c chdirs to dirname(argv[0]); conf.c opens "../services.conf";
#   lang.c opens "../lang.conf"; data files live under ../data/.
# We mirror that at /opt/azzurra/services/.
RUN useradd -r -s /usr/sbin/nologin -d /var/lib/services services \
 && mkdir -p /opt/azzurra/services/bin /opt/azzurra/services/lang /var/lib/services \
 && chown -R services: /opt/azzurra /var/lib/services
COPY --from=build /src/services /opt/azzurra/services/bin/services
COPY --from=build /src/lang /opt/azzurra/services/lang
COPY --from=build /src/run/data /opt/azzurra/services/data
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY conf.tmpl /opt/azzurra/services/services.conf.tmpl
RUN chmod +x /usr/local/bin/entrypoint.sh \
 && chown -R services: /opt/azzurra
USER services
WORKDIR /opt/azzurra/services
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

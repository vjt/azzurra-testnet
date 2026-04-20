# Azzurra testnet infra

Dockerized Azzurra test network: **hub + leaf-v4 + leaf-v6 + services**, via `docker compose up`. Dev and testnet only. **Not** a production install path — for that see `INSTALL.md` in [azzurra/bahamut](https://github.com/azzurra/bahamut) and [azzurra/services](https://github.com/azzurra/services).

## Topology

```
                       ┌─────────────────────────┐
                       │   services              │
                       │   services.azzurra.chat │
                       │   C/N link via hub-v4   │
                       └──────────┬──────────────┘
                                  │ svc-net (IPv4)
                       ┌──────────▼──────────────┐
                       │   hub                   │
                       │   hub.azzurra.chat      │
                       │   clients 6667/6697     │
                       │   S2S v4:7000 v6:7001   │
                       └──┬───────────────────┬──┘
                          │ leaf4-net (v4)    │ leaf6-net (v6 ULA)
                ┌─────────▼───────┐   ┌───────▼─────────┐
                │  leaf-v4        │   │  leaf-v6        │
                │  leaf4.azzurra  │   │  leaf6.azzurra  │
                │  S2S over v4    │   │  S2S over v6    │
                └─────────────────┘   └─────────────────┘
```

One `bahamut` image is built once and reused for all three ircds; `SERVER_ROLE` env selects the conf template (`hub` / `leaf4` / `leaf6`). Ensures the three binaries are identical — the only prod-relevant combination.

## Host ports

| Service | Plain | TLS   |
|---------|-------|-------|
| hub     | 6667  | 6697  |
| leaf-v4 | 6668  | 6698  |
| leaf-v6 | 6669  | 6699  |

Server-to-server ports (7000/v4, 7001/v6) stay on internal docker networks — not exposed to the host.

## Quickstart

```
cp .env.example .env
# edit .env as needed (defaults are testnet-safe)
docker compose up --build
```

On first run, `cert-init` generates throwaway self-signed certs under `certs/` (one per server), then hub/leaves/services start in order. `scripts/smoke.sh` runs a smoke-test against the stack.

To tear down and wipe services DB:

```
docker compose down -v
```

Plain `docker compose down` preserves the named volume `services-data`.

## Layout

```
.
├── compose.yaml          # top-level topology
├── .env.example          # knobs — copy to .env
├── bahamut/              # one image, three roles
│   ├── Dockerfile
│   ├── options.h_hub     # build-time knobs
│   ├── entrypoint.sh     # envsubst → ircd -F
│   ├── conf.hub.tmpl
│   ├── conf.leaf4.tmpl
│   └── conf.leaf6.tmpl
├── services/
│   ├── Dockerfile
│   ├── entrypoint.sh
│   └── conf.tmpl
├── certs/
│   └── gen-cert.sh       # throwaway self-signed, per server CN
├── scripts/
│   └── smoke.sh          # /map, cross-leaf whois, services round-trip
└── .github/workflows/
    └── testnet.yml       # CI: up --wait → smoke → down -v
```

## Non-goals

- Production TLS / real certs — throwaway self-signed only.
- Persistence across `down -v` — ephemeral by design.
- HAProxy / webirc / 6to4 / ident / bopm / stats / real-Azzurra links.
- More than two leaves or a second hub (not now — exercise v4 + v6 S2S paths and move on).

## Related

The greenfield 2026 reboot (REST+SSE server plus IRCv3 listener) lives at [`grappa-irc`](https://github.com/vjt/grappa-irc). This repo is plumbing for the existing legacy stack.

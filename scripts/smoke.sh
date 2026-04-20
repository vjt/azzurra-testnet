#!/bin/sh
# Minimal smoke test — brings the stack up, waits for S2S burst to settle,
# exits non-zero if hub/leaf4/leaf6/services are not all linked.
#
# This is deliberately shallow. It does not exercise NickServ round-trips
# or cross-leaf /whois — those belong in CI once the baseline topology
# verifies that a /links output on any node shows all four servers.
set -eu

cd "$(dirname "$0")/.."

echo "=== bringing stack up (detached) ==="
docker compose up -d --build --wait

echo "=== waiting for S2S burst (45s soft deadline) ==="
# bahamut logs "netinfo" / "link complete" style strings when S2S burst done.
# Poll hub's /stats links via a raw socket for up to 45s.
deadline=$(( $(date +%s) + 45 ))
while [ "$(date +%s)" -lt "${deadline}" ]; do
    links=$(printf 'NICK smoke\r\nUSER smoke 0 * :smoke\r\nLINKS\r\nQUIT\r\n' \
        | (timeout 5 nc -w 4 127.0.0.1 6667 || true) \
        | grep -E ' 364 | 365 ' | awk '{print $5}' | sort -u | tr '\n' ' ')
    case "${links}" in
        *hub.azzurra.chat*leaf4.azzurra.chat*leaf6.azzurra.chat*services.azzurra.chat*)
            echo "=== burst settled: ${links}==="
            echo "OK"
            exit 0
            ;;
    esac
    sleep 2
done

echo "=== burst did not settle in time ==="
docker compose ps
docker compose logs --tail=80 hub leaf-v4 leaf-v6 services
exit 1

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

echo "=== pinging ChanServ (240s soft deadline) ==="
# End-to-end liveness probe, per Mezmerize's suggestion: PRIVMSG ChanServ :HELP
# and wait for a NOTICE back. If ChanServ replies, the whole chain is up:
# client → hub → services link → services pseudo-client → reply back through
# the link → hub → client. services is U-lined (hidden from /LINKS for
# non-opers) so a raw /LINKS count would require an O-line dance; CS HELP
# sidesteps that entirely and actually exercises the data path.
#
# Runs inside a throwaway alpine container attached to svc-net. From the
# host's published 6667, bahamut's reverse-DNS resolver (res.c) stalls on
# 127.0.0.1 because docker's embedded DNS has no PTR, so client registration
# stalls on ident/hostname timeouts and replies never land. From svc-net,
# docker's DNS answers and registration completes immediately.
#
# Y:60 autoconnect connfreq is 180s, and services handshake needs a beat
# more after leafs link, so 240s deadline.
probe_net="azzurra-testnet_svc-net"

deadline=$(( $(date +%s) + 240 ))
while [ "$(date +%s)" -lt "${deadline}" ]; do
    out=$(docker run --rm --network "${probe_net}" alpine:3.20 sh -c '
        apk add --no-cache netcat-openbsd >/dev/null 2>&1
        (printf "NICK smoke\r\nUSER smoke 0 * :smoke\r\n"; sleep 3;
         printf "PRIVMSG ChanServ :HELP\r\n"; sleep 4;
         printf "QUIT\r\n"; sleep 1) \
        | nc -w 10 hub.azzurra.chat 6667
    ' 2>/dev/null || true)
    # ChanServ lives on services.azzurra.chat; its replies arrive as
    # :ChanServ!service@azzurra.chat NOTICE smoke :...
    if printf '%s\n' "${out}" | grep -qE '^:ChanServ![^ ]+ (NOTICE|PRIVMSG) smoke '; then
        echo "=== ChanServ replied — end-to-end green ==="
        printf '%s\n' "${out}" | grep -E '^:ChanServ' | head -5
        echo "OK"
        exit 0
    fi
    sleep 3
done

echo "=== no ChanServ reply within deadline ==="
docker compose ps
docker compose logs --tail=120 hub leaf-v4 leaf-v6 services
exit 1

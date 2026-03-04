#!/bin/sh
set -e

if [ $# -lt 1 ]; then
	echo "Usage: $0 [ip:]<remote_port> [local_port] [cert_file]"
	echo ""
	echo "Listens on http://localhost:<local_port> and forwards to https://<remote_host>:<remote_port>"
	echo "Default remote host: llama-runpod"
	echo "Default local port:  10000"
	echo "Default cert file:   server.crt"
	echo ""
	echo "Examples:"
	echo "  $0 443"
	echo "  $0 443 10000"
	echo "  $0 192.168.1.50:443"
	echo "  $0 192.168.1.50:443 10000"
	echo "  $0 192.168.1.50:443 10000 my-cert.crt"
	exit 1
fi

REMOTE_HOST="llama-runpod"
REMOTE_PORT="443"

# Parse first arg as [ip:]port
case "$1" in
*:*)
	REMOTE_HOST="${1%%:*}"
	REMOTE_PORT="${1##*:}"
	;;
*)
	REMOTE_PORT="$1"
	;;
esac

LOCAL_PORT="${2:-19687}"
CERT_FILE="${3:-server.crt}"

if ! command -v socat >/dev/null 2>&1; then
	echo "Error: socat is required but not installed" >&2
	echo "  apt install socat" >&2
	echo "  brew install socat" >&2
	exit 1
fi

if [ ! -f "$CERT_FILE" ]; then
	echo "Error: certificate file not found: ${CERT_FILE}" >&2
	exit 1
fi

echo "Proxying http://localhost:${LOCAL_PORT} → https://${REMOTE_HOST}:${REMOTE_PORT}"
echo "Verifying server with: ${CERT_FILE}"
exec socat "TCP-LISTEN:${LOCAL_PORT},fork,reuseaddr" "OPENSSL:${REMOTE_HOST}:${REMOTE_PORT},cafile=${CERT_FILE},commonname=llama-runpod"

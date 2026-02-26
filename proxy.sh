#!/bin/sh
set -e

if [ $# -lt 1 ]; then
  echo "Usage: $0 <local_port> [ip:]<remote_port>"
  echo ""
  echo "Listens on http://localhost:<local_port> and forwards to https://<remote_host>:<remote_port>"
  echo "Default remote: llama-runpod:443"
  echo ""
  echo "Examples:"
  echo "  $0 8080"
  echo "  $0 8080 443"
  echo "  $0 8080 192.168.1.50:443"
  exit 1
fi

LOCAL_PORT="$1"
REMOTE_HOST="llama-runpod"
REMOTE_PORT="443"

# Parse optional second arg as [ip:]port
if [ -n "$2" ]; then
  case "$2" in
    *:*)
      REMOTE_HOST="${2%%:*}"
      REMOTE_PORT="${2##*:}"
      ;;
    *)
      REMOTE_PORT="$2"
      ;;
  esac
fi

if ! command -v socat >/dev/null 2>&1; then
  echo "Error: socat is required but not installed" >&2
  echo "  apt install socat" >&2
  echo "  brew install socat" >&2
  exit 1
fi

echo "Proxying http://localhost:${LOCAL_PORT} → https://${REMOTE_HOST}:${REMOTE_PORT}"
exec socat "TCP-LISTEN:${LOCAL_PORT},fork,reuseaddr" "OPENSSL:${REMOTE_HOST}:${REMOTE_PORT},verify=0"

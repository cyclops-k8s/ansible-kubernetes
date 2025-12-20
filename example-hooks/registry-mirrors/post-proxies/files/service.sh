#!/bin/bash

set -euo pipefail

usage()
{
  echo "Usage: $0

  -c | --config     Path to the configuration file.
  -d | --data-path  Path to the data directory.
  -g | --gid        GID to run the container as.
  -i | --image      Docker image to use.
  -n | --name       Name of the container.
  -p | --port       Port to expose the container on.
  -s | --state      State of the container (start|stop).
  -u | --uid        UID to run the container as.
"
  exit 1
}

# Store the command line arguments as a variable
PARSED_ARGUMENTS=$(getopt -a -n "$0" -o c:d:g:i:n:p:s:u: --long config:,data-path:,gid:,image:,name:,port:,state:,uid: -- "$@")
VALID_ARGUMENTS=$?

# Make sure some arguments were passed in
if [ "$VALID_ARGUMENTS" != "0" ];
then
  usage
fi

eval set -- "$PARSED_ARGUMENTS"

CONFIG="${CONFIG:-}"
PORT="${PORT:-}"
IMAGE="${IMAGE:-}"
MIRROR_UID="${MIRROR_UID:-}"
MIRROR_GID="${MIRROR_GID:-}"
DATA_PATH="${DATA_PATH:-}"
STATE="${STATE:-}"
NAME="${NAME:-}"

while :
do
  case "$1" in
    -c | --config) CONFIG="$2"; shift 2 ;;
    -d | --data-path) DATA_PATH="$2"; shift 2 ;;
    -g | --gid) MIRROR_GID="$2"; shift 2 ;;
    -i | --image) IMAGE="$2"; shift 2 ;;
    -n | --name) NAME="$2"; shift 2 ;;
    -p | --port) PORT="$2"; shift 2 ;;
    -s | --state) STATE="$2"; shift 2 ;;
    -u | --uid) MIRROR_UID="$2"; shift 2 ;;
    -h | --help) usage;;
    --) shift; break ;;
    *) usage;;
  esac
done

if [ -z "${PORT}" ] || \
   [ -z "${IMAGE}" ] || \
   [ -z "${MIRROR_UID}" ] || \
   [ -z "${MIRROR_GID}" ] || \
   [ -z "${DATA_PATH}" ] || \
   [ -z "${CONFIG}" ] || \
   [ -z "${STATE}" ] || \
   [ -z "${NAME}" ]
then
  usage
fi

if ! [[ "${MIRROR_UID}" =~ ^[0-9]+$ ]]
then
  echo "UID must be a number"
  exit 1
fi

if ! [[ "${MIRROR_GID}" =~ ^[0-9]+$ ]]
then
  echo "GID must be a number"
  exit 1
fi

if ! [[ "${PORT}" =~ ^[0-9]+$ ]]
then
  echo "Port must be a number"
  exit 1
fi

[ -f "${CONFIG}" ] || { echo "Config file ${CONFIG} does not exist"; exit 1; }
if [ ! -d "${DATA_PATH}" ]
then
  echo "Data path ${DATA_PATH} does not exist"
  mkdir -p "${DATA_PATH}"
  echo "Created data path ${DATA_PATH}"
  echo "Setting permissions on data path ${DATA_PATH} to ${MIRROR_UID}:${MIRROR_GID}"
  chown -R "${MIRROR_UID}:${MIRROR_GID}" "${DATA_PATH}"
fi

if [ "${STATE}" == "start" ]
then
  /usr/bin/docker stop "${NAME}" || true
  /usr/bin/docker rm "${NAME}" || true
  echo "******************* Starting mirror container ${NAME} on port ${PORT} *******************"

  docker run -d --name "${NAME}" \
    -v "${DATA_PATH}:/var/lib/registry" \
    -v "${CONFIG}:/etc/distribution/config.yml:ro" \
    -p "${PORT}:5000" \
    --user "${MIRROR_UID}:${MIRROR_GID}" \
    --read-only \
    "${IMAGE}"

  echo "******************* Waiting for mirror container ${NAME} on port ${PORT} to start *******************"
  # wait for the container to be ready
  until curl "http://localhost:${PORT}/v2/" -f --silent --max-time 2 >/dev/null 2>&1
  do
    sleep 1
  done
  echo "******************* Started mirror container ${NAME} on port ${PORT} *******************"

  systemd-notify --ready --status="Mirror ${NAME} is running on port ${PORT}"

  # Start a background process to send watchdog notifications as long as we can curl the container
  bash -c "
    while true
    do
      if curl \"http://localhost:${PORT}/v2/\" -f --silent --max-time 2 >/dev/null 2>&1
      then
        systemd-notify WATCHDOG=1 || echo \"Failed to send watchdog notification for mirror ${NAME}\"
      else
        echo \"Mirror ${NAME} on ${PORT} is not responding\"
      fi
      sleep 10
    done
  " &
  HEALTHCHECK_PID=$!

  # Trap to clean up background health check on exit
  trap 'kill ${HEALTHCHECK_PID} 2>/dev/null || true' EXIT TERM INT

  docker logs -f --since 30s "${NAME}" # This should run for the lifetime of the container and send the logs to journald
elif [ "${STATE}" == "stop" ]
then
  docker stop "${NAME}" || true
  docker rm "${NAME}" || true
else
  echo "Invalid state: ${STATE}"
  exit 1
fi

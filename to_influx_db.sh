#!/bin/sh
#
# Adapted from https://github.com/tomru/cram-luftdaten.git
# TODO: explain usage

set -e

HOST=${INFLUXDB_HOST:-localhost}
PORT=${INFLUXDB_PORT:-8086}
DATABASE=${INFLUXDB_DATABASE:-None}
PRECISION=${INFLUXDB_PRECISION:-s}

SRC_FILE=${1:-/dev/stdin}

curl -sS --include -X POST \
    "http://${HOST}:${PORT}/write?db=${DATABASE}&precision=${PRECISION}" \
    --data-binary @${SRC_FILE}

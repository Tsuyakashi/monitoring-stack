#!/bin/bash

if [ "${EUID}" -ne 0 ]; then
    echo "You need to run this script as root"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd ${SCRIPT_DIR}/.. && sudo docker compose up -d

# Configure kibana
"${SCRIPT_DIR}/kibana-setup.sh" || echo "Kibana configuration failed"


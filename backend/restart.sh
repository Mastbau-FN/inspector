#!/usr/bin/env bash
set -euo pipefail

cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

git checkout staging
git pull --ff-only

docker-compose config --quiet

sysctl -w net.ipv4.ip_unprivileged_port_start=442

docker-compose down
docker-compose up -d
docker logs -f backend_node-api-server_1

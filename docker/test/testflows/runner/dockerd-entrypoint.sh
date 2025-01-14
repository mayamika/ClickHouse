#!/bin/bash
set -e

echo "Configure to use Yandex dockerhub-proxy"
mkdir -p /etc/docker/
cat > /etc/docker/daemon.json << EOF
{
    "insecure-registries" : ["dockerhub-proxy.dockerhub-proxy-zone:5000"],
    "registry-mirrors" : ["http://dockerhub-proxy.dockerhub-proxy-zone:5000"]
}
EOF

# In case of test hung it is convenient to use pytest --pdb to debug it,
# and on hung you can simply press Ctrl-C and it will spawn a python pdb,
# but on SIGINT dockerd will exit, so ignore it to preserve the daemon.
trap '' INT
dockerd --host=unix:///var/run/docker.sock --host=tcp://0.0.0.0:2375 &>/var/log/somefile &

set +e
reties=0
while true; do
    docker info &>/dev/null && break
    reties=$((reties+1))
    if [[ $reties -ge 100 ]]; then # 10 sec max
        echo "Can't start docker daemon, timeout exceeded." >&2
        exit 1;
    fi
    sleep 0.1
done
set -e

echo "Start tests"
export CLICKHOUSE_TESTS_SERVER_BIN_PATH=/clickhouse
export CLICKHOUSE_TESTS_CLIENT_BIN_PATH=/clickhouse
export CLICKHOUSE_TESTS_BASE_CONFIG_DIR=/clickhouse-config
export CLICKHOUSE_ODBC_BRIDGE_BINARY_PATH=/clickhouse-odbc-bridge

cd /ClickHouse/tests/testflows
exec "$@"

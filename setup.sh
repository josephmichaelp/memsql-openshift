#!/bin/bash
set -e
set -x

# Expects this file to export $OPS_VERSION and $MEMSQL_VERSION
source /tmp/VERSIONS

VERSION_URL="http://versions.memsql.com/memsql-ops/$OPS_VERSION"
MEMSQL_VOLUME_PATH="/memsql"
OPS_URL=$(curl -s "$VERSION_URL" | jq -r .payload.tar)

# setup memsql user
groupadd -r memsql --gid 1000
useradd -r -g memsql -s /bin/false --uid 1000 \
    -d /var/lib/memsql-ops -c "MemSQL Service Account" \
    memsql

# download ops
curl -s $OPS_URL -o /tmp/memsql_ops.tar.gz

# install ops
mkdir /tmp/memsql-ops
tar -xzf /tmp/memsql_ops.tar.gz -C /tmp/memsql-ops --strip-components 1
/tmp/memsql-ops/install.sh \
    --host 127.0.0.1 \
    --no-cluster \
    --ops-datadir /memsql-ops \
    --memsql-installs-dir /data \
    --ignore-min-requirements

chgrp -R 0   /memsql-ops
chmod -R g=u /memsql-ops

memsql-ops stop

# cleanup
rm -rf /memsql-ops/data/cache/*

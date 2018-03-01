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
    --memsql-installs-dir /memsql-ops/installs \
    --ignore-min-requirements

DEPLOY_EXTRA_FLAGS=
if [[ $MEMSQL_VERSION != "developer" ]]; then
    DEPLOY_EXTRA_FLAGS="--version-hash $MEMSQL_VERSION"
fi

memsql-ops memsql-deploy --role master --developer-edition $DEPLOY_EXTRA_FLAGS || echo "Ignoring error"
memsql-ops memsql-deploy --role leaf --developer-edition --port 3307 $DEPLOY_EXTRA_FLAGS || echo "Ignoring error"

memsql-ops memsql-update-config --all --key minimum_core_count --value 0
memsql-ops memsql-update-config --all --key minimum_memory_mb --value 0

MASTER_ID=$(memsql-ops memsql-list --memsql-role=master -q)
memsql-ops memsql-update-config --key "socket" --value /tmp/master-memsql.sock ${MASTER_ID}

LEAF_ID=$(memsql-ops memsql-list --memsql-role=leaf -q)
memsql-ops memsql-update-config --key "socket" --value /tmp/leaf-memsql.sock ${LEAF_ID}

chgrp -R 0   /memsql-ops
chmod -R g=u /memsql-ops

memsql-ops memsql-stop --all
memsql-ops stop

# cleanup
rm -rf /tmp/*
rm -rf /memsql-ops/data/cache/*

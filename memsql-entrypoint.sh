#!/bin/bash
set -e
set -x

source /tmp/VERSIONS

export POD_NAME=$(hostname)
export POD_ORDINAL=${POD_NAME##*-}
export STATEFULSET_NAME=$(echo "${POD_NAME}" | sed -e 's/-[0-9]*$//g')

if ! whoami &> /dev/null; then
  echo "Creating user UID entry..."
  if [ -w /etc/passwd ]; then
    sed -i '/memsql:/d' /etc/passwd
    echo "memsql:x:$(id -u):0:MemSQL Service Account:/var/lib/memsql-ops:/bin/bash" >> /etc/passwd
  fi
  echo "User UID created."
fi

if [[ "$1" = "memsqld" ]]; then
    MEMORY_LIMIT=$(echo | awk '{ print int('${MEMORY_LIMIT}'*0.8 /1024/1024)}')

    sed -i '/user = memsql/d' /var/lib/memsql-ops/settings.conf
    sed -i "/started_as_root/c started_as_root = False" /var/lib/memsql-ops/settings.conf
    sed -i "/ops_datadir = /c ops_datadir = /memsql-ops" /var/lib/memsql-ops/settings.conf
    sed -i "/host =/c host = $(hostname)" /var/lib/memsql-ops/settings.conf
    echo "debug = True" >> /var/lib/memsql-ops/settings.conf

    rm -f /memsql-ops/memsql-ops.log
    memsql-ops start --ignore-root-error

    if [[ "$(hostname)" == *"-0" ]]; then
        NODE_ROLE="master"
    else
        NODE_ROLE="leaf"
    fi

    if [ ! "$(ls -A /data)" ]; then
        if [[ "${NODE_ROLE}" == "leaf" ]]; then
            memsql-ops follow --host ${STATEFULSET_NAME}-0
        fi
        memsql-ops memsql-deploy --role ${NODE_ROLE} --developer-edition --version-hash ${MEMSQL_VERSION} || echo "Ignore errors"
        export NODE_ID=$(memsql-ops memsql-list -q)

        memsql-ops memsql-update-config --key minimum_core_count --value 0 ${NODE_ID}
        memsql-ops memsql-update-config --key minimum_memory_mb --value 0 ${NODE_ID}
        memsql-ops memsql-update-config --key socket --value /tmp/memsql.sock ${NODE_ID}

        memsql-ops memsql-start --all
        memsql-ops memsql-list

#        memsql-ops memsql-update-config --key maximum_memory --value ${MEMORY_LIMIT} ${NODE_ID}

        if [[ "${NODE_ROLE}" == "master" ]]; then
            memsql-ops memsql-update-config --set-global --key default_partitions_per_leaf --value ${PARTITIONS_PER_LEAF:-2} ${NODE_ID}
        fi
    else
        memsql-ops memsql-start --all
        memsql-ops memsql-list
    fi

    # Check for a schema file at /schema/data.sql and load it
    if [[ -e /schema/data.sql ]]; then
        echo "Loading schema from /schema.sql"
        memsql < /schema/data.sql
    fi

    # Tail the logs to keep the container alive
    exec tail -F /data/*/tracelogs/memsql.log
else
    exec "$@"
fi

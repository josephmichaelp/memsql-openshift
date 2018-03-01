#!/bin/bash
set -e
set -x

if ! whoami &> /dev/null; then
  echo "Creating user UID entry..."
  if [ -w /etc/passwd ]; then
    sed -i '/memsql:/d' /etc/passwd
    echo "memsql:x:$(id -u):0:MemSQL Service Account:/var/lib/memsql-ops:/bin/bash" >> /etc/passwd
  fi
  echo "User UID created."
fi

function init_node_directory {
    local node_role=$1

    export node_id=$(memsql-ops memsql-list --memsql-role=${node_role} -q)
    export node_path=$(memsql-ops memsql-path ${node_id})

    if [[ ! -e /data/${node_role} ]]; then
        mv ${node_path} /data/${node_role}
    else
        rm -rf ${node_path}
    fi

    ln -s /data/${node_role} ${node_path}
}

if [[ "$1" = "memsqld" ]]; then
    MEMORY_LIMIT=$(echo | awk '{ print '${MEMORY_LIMIT}'*0.8 /1024/1024}')

    sed -i '/user = memsql/d' /var/lib/memsql-ops/settings.conf
    sed -i "/started_as_root/c started_as_root = False" /var/lib/memsql-ops/settings.conf
    sed -i "/ops_datadir = /c ops_datadir = /memsql-ops" /var/lib/memsql-ops/settings.conf
    sed -i "/host =/c host = $(hostname)" /var/lib/memsql-ops/settings.conf
    echo "debug = True" >> /var/lib/memsql-ops/settings.conf

    rm -f /memsql-ops/memsql-ops.log
    memsql-ops start --ignore-root-error

    #Eliminate Minimum Core Count Requirement
    memsql-ops memsql-update-config --all --key minimum_core_count --value 0
    memsql-ops memsql-update-config --all --key minimum_memory_mb --value 0

    init_node_directory master
    init_node_directory leaf

    memsql-ops memsql-start --all
    memsql-ops memsql-list

    memsql-ops memsql-update-config --set-global --key default_partitions_per_leaf --value ${PARTITIONS_PER_LEAF:-2} $(memsql-ops memsql-list --memsql-role=master -q)
    memsql-ops memsql-update-config --all --key maximum_memory --value ${MEMORY_LIMIT} --all

    # Check for a schema file at /schema.sql and load it
    if [[ -e /schema.sql ]]; then
        echo "Loading schema from /schema.sql"
        cat /schema.sql
        memsql < /schema.sql
    fi

    # Tail the logs to keep the container alive
    exec tail -F /data/*/tracelogs/memsql.log
else
    exec "$@"
fi

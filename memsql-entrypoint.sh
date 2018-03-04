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
    exec /etc/memsql-ops/memsql-ops -f --ignore-root-error
else
    exec "$@"
fi

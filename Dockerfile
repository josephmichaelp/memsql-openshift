#
# MemSQL Quickstart Dockerfile
#
# https://github.com/memsql/memsql-docker-quickstart
#

FROM debian:8.6
MAINTAINER Carl Sverre <carl@memsql.com>

RUN apt-get update || apt-get update \
    apt-get install -y \
        libmysqlclient-dev \
        mysql-client \
        curl \
        jq \
        python-dev \
        python-pip \
        net-tools \
        netcat \
    && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# install useful python packages
RUN pip install --upgrade pip
RUN pip install memsql ipython psutil

# configure locale for utf-8
RUN apt-get update && apt-get install -y locales && rm -rf /var/lib/apt/lists/* \
    && localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
ENV LANG en_US.utf8

# set UTC
RUN ln -sf /usr/share/zoneinfo/UTC /etc/localtime

# setup directories
RUN mkdir /data /memsql-ops

# download and install MemSQL Ops
# then reduce size by symlinking objdir and lib from one install to the other
COPY setup.sh /tmp/setup.sh
COPY VERSIONS /tmp/VERSIONS
RUN /tmp/setup.sh

# COPY helper scripts
COPY memsql-shell /usr/local/bin/memsql-shell
COPY check-system /usr/local/bin/check-system
COPY simple-benchmark /usr/local/bin/simple-benchmark

COPY memsql-entrypoint.sh /

RUN chgrp -R 0   /data /memsql-ops /tmp /var /etc && \
    chmod -R g=u /data /memsql-ops /tmp /var /etc

VOLUME ["/data"]

ENTRYPOINT ["/memsql-entrypoint.sh"]
CMD ["memsqld"]

# expose ports
EXPOSE 3306 3307 9000 8443

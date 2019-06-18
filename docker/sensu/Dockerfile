# Source
FROM ubuntu:18.04

# Labels
LABEL vendor=Sensu,\ Inc. \
  org.sensuapp.version="1.7.0" \
  org.sensuapp.release-date="2019-02-19"

# Build arguments
ARG SENSU_REPO_HOST=http://sensu.global.ssl.fastly.net
ARG SENSU_REPO_PATH=/apt/pool/bionic/main/s/sensu
ARG SENSU_PACKAGE_VERSION=1.7.0-2
ARG SENSU_PACKAGE_ARCH=amd64
ARG SENSU_PACKAGE_FORMAT=deb

# Environment Variables
ENV \
  SENSU_LOG_LEVEL="info" \
  SENSU_CLIENT_SUBSCRIPTIONS="all,docker" \
  SENSU_TRANSPORT_NAME="redis" \
  REDIS_URL="redis://${SENSU_REDIS_SERVICE_HOST:-127.0.0.1}:${SENSU_REDIS_SERVICE_PORT:-6379}"

# Build instructions
WORKDIR /tmp
RUN \
  apt-get update && apt-get install -y \
  wget build-essential && \
  wget ${SENSU_REPO_HOST}/${SENSU_REPO_PATH}/sensu_${SENSU_PACKAGE_VERSION}_${SENSU_PACKAGE_ARCH}.${SENSU_PACKAGE_FORMAT} && \
  dpkg -i sensu_${SENSU_PACKAGE_VERSION}_${SENSU_PACKAGE_ARCH}.${SENSU_PACKAGE_FORMAT} && \
  rm -f sensu_${SENSU_PACKAGE_VERSION}_${SENSU_PACKAGE_ARCH}.${SENSU_PACKAGE_FORMAT} && \
  echo "EMBEDDED_RUBY=true" | tee /etc/default/sensu && \
  /opt/sensu/embedded/bin/gem install rest-client && \
  apt-get remove --purge build-essential -y --force-yes && \
  /opt/sensu/bin/sensu-client --print_config -d /etc/sensu/conf.d/ && \
  /opt/sensu/bin/sensu-install -p http && \
  /opt/sensu/bin/sensu-install -p sensu-plugins-influxdb

COPY files/deregistration.rb /etc/sensu/plugins/deregistration.rb
COPY files/deregistration_kubernetes.rb /etc/sensu/plugins/deregistration_kubernetes.rb
COPY files/sensu-prometheus-collector /usr/bin/sensu-prometheus-collector
RUN chmod +x /usr/bin/sensu-prometheus-collector


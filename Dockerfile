# Dockerfile with custom Kafka Connect Plugins
# Currently includes the following added plugins:
# confluentinc-kafka-connect-omnisci-1.0.1-preview

FROM registry.redhat.io/amq7/amq-streams-kafka-connect:1.1.0-kafka-2.1.1
LABEL maintainer="Dan Clark <danclark@redhat.com>"
USER root:root
COPY ./plugins/ /opt/kafka/plugins/
USER kafka:kafka

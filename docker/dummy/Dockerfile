FROM alpine:latest

RUN apk --no-cache add curl
COPY dummy /usr/bin/dummy
COPY sensu-prometheus-collector /usr/bin/sensu-prometheus-collector

RUN chmod +x /usr/bin/sensu-prometheus-collector

EXPOSE 8080

CMD ["/usr/bin/dummy"]


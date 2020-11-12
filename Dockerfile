FROM alpine:3.12

MAINTAINER Eugene Klimov <eklimov@altinity.com>

RUN apk --no-cache add fio

VOLUME /data
WORKDIR /data
COPY ./docker-entrypoint.sh /
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["fio"]

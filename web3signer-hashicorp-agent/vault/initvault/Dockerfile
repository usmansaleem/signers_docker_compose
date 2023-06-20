FROM alpine:latest

RUN apk update &&       \
    apk add --no-cache curl jq bash &&  \
    rm -rf /var/cache/apk/*


COPY ./init-vault.sh /
RUN chmod +x /init-vault.sh

VOLUME /creds

ENTRYPOINT ["/init-vault.sh"]

FROM alpine:latest

RUN apk update && apk add --no-cache openssl && \
    rm -rf /var/cache/apk/*

COPY ./gen-cert.sh /usr/local/bin/gen-cert.sh
RUN chmod 755 /usr/local/bin/gen-cert.sh

VOLUME /certs
VOLUME /web3signer/config

ENTRYPOINT ["/usr/local/bin/gen-cert.sh"]

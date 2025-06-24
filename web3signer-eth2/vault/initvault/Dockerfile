FROM alpine:latest

RUN apk update && apk add --no-cache curl jq bash && \
    rm -rf /var/cache/apk/* && \
    adduser -D -g '' vaultinit

COPY ./init-vault.sh /home/vaultinit/
RUN chmod 750 /home/vaultinit/init-vault.sh && \
    chown vaultinit:root /home/vaultinit/init-vault.sh

USER vaultinit
VOLUME /creds
WORKDIR /home/vaultinit

ENTRYPOINT ["/home/vaultinit/init-vault.sh"]
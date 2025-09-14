
### Samba Server
# 10.09.25

FROM alpine:latest
RUN apk update
RUN apk add --no-cache samba samba-common-tools
RUN mkdir -p  /var/lib/samba/music \
    && chown -R nobody:nogroup /var/lib/samba/music \
    && chmod -R 777 /var/lib/samba/music
CMD ["sh", "-c", "smbd -F --no-process-group"]

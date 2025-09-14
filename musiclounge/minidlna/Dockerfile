
#### MiniDLNA
# 10.09.25

FROM alpine:latest
RUN apk update
RUN apk add --no-cache minidlna
CMD ["minidlnad", "-S", "-f", "/etc/minidlna.conf"]


# 10.06.25

# FROM alpine
# FROM python:alpine
FROM python:3.12-alpine
WORKDIR /app
# COPY ./etc/upmpdcli.conf /etc/
RUN apk update
RUN apk --no-cache add upmpdcli openssl
RUN pip install --upgrade pip 
RUN pip install requests 
# CMD ["upmpdcli", "-c", "/etc/upmpdcli.conf", "-h", "$MPD_IP_ADDR"]
CMD ["upmpdcli", "-c", "/etc/upmpdcli.conf"]

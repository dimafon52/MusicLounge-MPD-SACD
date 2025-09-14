
# FROM alpine
FROM python:3.12-alpine
WORKDIR /app
EXPOSE 80 443
COPY ./update_ver_of_myMPD.sh .
RUN apk update
RUN apk --no-cache add git 
RUN apk --no-cache add libmpdclient flac libid3tag mpc 
RUN chmod +x update_ver_of_myMPD.sh
RUN /bin/sh update_ver_of_myMPD.sh
# Clean sources
RUN rm -rf myMPD
RUN pip install --upgrade pip && pip install python-mpd2
# RUN mkdir -p /var/lib/mympd/
# COPY ./mympd_config/* /var/lib/mympd/
# RUN mkdir -p /var/lib/mympd/config /var/lib/mympd/state && \
#     echo 8080 > /var/lib/mympd/config/http_port && \
#     echo false > /var/lib/mympd/config/ssl && \
#     echo 192.168.0.110 > /var/lib/mympd/state/mpd_host
# CMD ["mympd", "--version", "&&", "mympd"]
# RUN mkdir -p /var/lib/mympd/config /var/lib/mympd/state && \
#     echo false > /var/lib/mympd/config/ssl && \
#     echo 80 > /var/lib/mympd/config/http_port && \
#     echo ${MPD_IP_ADDR} > /var/lib/mympd/state/mpd_host
# RUN ls -l /var/lib/mympd
# CMD [ "mympd"]
CMD mympd

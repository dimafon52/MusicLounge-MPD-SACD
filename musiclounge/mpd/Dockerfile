#### 05.08.25
#### MPD 
ARG MPD_BUILD_VERSION="0.0.1"
# FROM dimafon/archmpd:24.3
FROM dimafon/archmpd-sacd:0.24.3-5
ARG MPD_BUILD_VERSION
ENV MPD_BUILD_VERSION=${MPD_BUILD_VERSION}
WORKDIR /var/lib/mpd
RUN set -exu
RUN mkdir -p playlists
RUN mkdir -p music
RUN mkdir -p data
RUN touch \
    data/database \
    mpd.pid \
    data/state \
    data/sticker.sql

# RUN chown mpd:audio -R /var/lib/mpd
# RUN pacman -S --noconfirm alsa-utils
# MPD port, MPD stream port
EXPOSE 6600 8000
# ENTRYPOINT python -m http.server -d music/ 6680 &
# CMD ["/usr/bin/mpd", "--no-daemon", "--stderr", "--verbose"]
CMD ["/usr/bin/mpd", "--no-daemon", "--stderr"]

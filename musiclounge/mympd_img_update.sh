#!/usr/bin/env bash

# 13.08.25

echo " === Upadate mympd web client..."
docker images
echo " === Stop all containers"
# docker compose stop
docker stop mpd-mympd-1
docker container rm mpd-mympd-1
docker image rm mpd-mympd || exit 1
# Backup mympd config 
sudo chmod 777 -R ./mympd/var_lib_mympd
# rsync -azv --update --existing --delete ./mympd/var_lib_mympd/ ./mympd/mympd_config
rsync -av --update --existing --delete ./mympd/var_lib_mympd/ ./mympd/mympd_config
echo " === After remove:"
docker images
echo " * Build new mympd image from source"
docker compose build mympd --no-cache || exit 1
echo " === After build:"
docker images
echo " === Update: Successful"
echo " === Start..."
# docker compose up -d
docker compose up mympd -d

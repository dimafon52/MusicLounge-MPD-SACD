#!/bin/bash

# Update(build) myMPD

git clone https://github.com/jcorporation/myMPD.git
cd myMPD

# BUILD
./build.sh installdeps
./build.sh release

# INSTALL
./build.sh install

# mkdir -p /var/lib/mympd/config
# mkdir -p /var/lib/mympd/state
# echo 'false' > /var/lib/mympd/config/ssl
# echo $MPD_IP_ADDR > /var/lib/mympd/state/mpd_host

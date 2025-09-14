#!/usr/bin/env python3
# 15.04.24

from mpd import MPDClient
import os

if __name__ == '__main__':

    client = MPDClient()
    MPD_HOST = os.environ['MPD_IP_ADDR']

    try:
        client.disconnect()
        client.connect(MPD_HOST, 6600)
    except Exception as e:
        print(f" =!= {e}")
        exit(1)

    album = os.path.dirname(client.currentsong()['file'])
    client.stop()
    client.clear()
    client.add(album)
    client.play()

#!/usr/bin/python3

# 23.07.23

# {'file': 'Секрет/ Секрет [196929159] [1987]/10 - Секрет - Моя любовь на пятом этаже.flac', 'last-modified': '2023-07-18T09:40:41Z', 'format': '44100:16:2', 'title': 'Моя любовь на пятом этаже', 'album': 'Секрет', 'albumartist': 'Секрет', 'artist': 'Секрет', 'track': '10', 'disc': '1', 'date': '1987-01-01', 'composer': ['М. Леонидов', 'Н. Фоменко'], 'time': '180', 'duration': '179.925'},

# client.sticker_list('song', 'Секрет/ Секрет [196929159] [1987]/10 - Секрет - Моя любовь на пятом этаже.flac')
# {'elapsed': '0', 'lastPlayed': '1690038634', 'like': '1', 'mafa.bookmark': '74023@Моя любовь на пятом этаже', 'playCount': '2'}

# -----------
# https://python-mpd2.readthedocs.io/en/latest/topics/commands.html?highlight=tag#stickers
# MPDClient.sticker_find(type, uri, name)
# Searches the sticker database for stickers with the specified name, below the specified directory (URI). For each matching song, it prints the URI and that one sticker’s value.

# MPDClient.sticker_find(type, uri, name, "=", value)
# Returns the results of a search for stickers with the given value.
# Other supported operators are: “<”, “>”


from mpd import MPDClient
import os


def play_like_songs():
    mpd_client.stop()
    mpd_client.clear()

    like_songs = mpd_client.sticker_find('song','','like','=',2)
    # print(f" === like_songs: {like_songs}")
    # print("---------------------------------")
    for like_song in like_songs:
        # print(f" - like_song: {like_song}")
        mpd_client.add(like_song['file'])
    # print("---------------------------------")
    # songs_data = mpd_client.listallinfo()
    # number = 1
    # for song_data in songs_data:
    #     try:
    #         like = mpd_client.sticker_get('song', song_data['file'], 'like')
    #     except:
    #         like = None

    #     if like == '2':
    #         uri  = song_data['file']
    #         name = song_data['title']
    #         print(f" {number}) {uri}")
    #         print(f"    {name}")
    #         number +=1
    #         mpd_client.add(uri)
    
    mpd_client.play()
    
    
if __name__ == '__main__':
    
    mpd_client = MPDClient()
    MPD_HOST = os.environ['MPD_IP_ADDR']
    
    try:
        mpd_client.disconnect()
        mpd_client.connect(MPD_HOST, 6600)
        #mpd_status = mpd_client.status()
    except Exception as e:
        print(f" =!= {e}")
        exit(1)

    play_like_songs()

    mpd_client.close()
    mpd_client.disconnect()
    

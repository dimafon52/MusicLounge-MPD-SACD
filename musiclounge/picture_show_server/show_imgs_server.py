#!/usr/bin/env python

# 07.09.25

from flask import Flask, render_template_string, jsonify, send_from_directory
import os, time, requests
import shutil, datetime
from PIL import Image
from io import BytesIO
# from duckduckgo_search import DDGS
from ddgs import DDGS
from mpd import MPDClient

# pip install -U duckduckgo_search
# yay -Sy --noconfirm python-duckduckgo-search

# pip install flask
# yay -Sy --noconfirm python-flask

prev_query = ""
IMAGES_GEN = None
IMAGES_MAX_RESULTS = 60
IMAGE_MINIMAL_SIZE = 500
DISPLAY_HIGH = 1200
# HOME_DIR = os.environ.get('HOME')
# IMAGE_FOLDER = f"{HOME_DIR}/tmp/show_images_tmp"
IMAGE_FOLDER = './show_img_srv'

# MPD_ADDR = "192.168.0.110"
MPD_ADDR = os.environ['MPD_IP_ADDR']
mpd_client = MPDClient()

import requests
from stem import Signal
from stem.control import Controller

TOR_PORT = 9050
TOR_CTRL_PORT = TOR_PORT + 1
TOR_PASSWD = "torpassword"

HOST="127.0.0.1"

PROXY=f"socks5h://{HOST}:{TOR_PORT}"

proxies = {
    "http": f"socks5h://{HOST}:{TOR_PORT}",
    "https": f"socks5h://{HOST}:{TOR_PORT}",
}

def tor_renew_ip():
    with Controller.from_port(port=TOR_CTRL_PORT) as c:
        # c.authenticate("")  # пустая строка, т.к. без пароля
        c.authenticate(TOR_PASSWD)  # пустая строка, т.к. без пароля
        c.signal(Signal.NEWNYM)

def tor_get_proxy_ip():
    r = requests.get("https://api.ipify.org?format=json", proxies=proxies, timeout=10)
    return r.json()["ip"]

def tor_get_real_ip():
    return requests.get("https://api.ipify.org?format=json").json()["ip"]


def mpd_get_albumartist():
    # global mpd_client
    try:
        # print(f" ==== MPD_ADDR: {MPD_ADDR}")
        mpd_client.disconnect()
        mpd_client.connect(MPD_ADDR, 6600)
        song_data = mpd_client.currentsong()
        if "artist" in song_data:
            albumartist = song_data["artist"]
        else:
            albumartist = song_data["title"].split(" - ")[0] # for radio station
        # print(f"OK")
    except Exception as e:
        print(f" =!= mpd_get_albumartist: {e}")
        albumartist = "nature"
    # print(f" +++ {mpd_client.playlistinfo()[0]}")
    mpd_client.close()
    mpd_client.disconnect()
    return albumartist

app = Flask(__name__)

TEMPLATE = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Image Viewer</title>
    <style>
        body {
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            margin: 0;
            background-color: #242432;
        }
        .container {
            text-align: center;
        }
        img {
            max-width: 99%;
            max-height: 99vh;
            border-radius: 10px;
            box-shadow: 0 4px 8px rgba(0, 0, 0, 0.2);
        }
    </style>
    <script>
        function updateImage() {
            fetch("/image").then(response => response.json()).then(data => {
                if (data.filename) {
                    var img = document.getElementById("image");
                    img.src = "/static_image/" + data.filename  + "?" + new Date().getTime();
                }
            });
        }
        setInterval(updateImage, 10000);
        window.onload = updateImage;
    </script>
</head>
<body>
    <div class="container">
        <img id="image" src="" alt="Loading image...">
    </div>
</body>
</html>
"""

## img.src = "/static_image/" + data.filename + "?" + new Date().getTime();
#<img src="file:///home/dima/tmp/show_images_tmp/TheBeatles_7.jpg" alt="file:///home/dima/tmp/show_images_tmp/TheBeatles_7.jpg" width="773" height="592" class="shrinkToFit">
# <style type="text/css" id="dark-mode-custom-style"></style>
# <link type="text/css" id="dark-mode" rel="stylesheet" href=""></link>


query = "The Beatles"
# query = "BBC Big Band"
# query = "Luis Armstrong"
# # query = "Pink Floyd"

# {'title': "Seth MacFarlane's 2024 Net Worth: A Billionaire's Empire",
# 'image': 'https://wealthypeeps.com/wp-content/uploads/2022/02/Seth-MacFarlane.jpg',
# 'thumbnail': 'https://tse2.mm.bing.net/th?id=OIP.8eam7CROemZXiJWZnwU8IgHaK5&pid=Api',
# 'url': 'https://crimemap.abc15.com/writing/seth-macfarlane-net-worth-2024',
# 'height': 2048, 'width': 1391, 'source': 'Bing'}

# {'title': 'Massimo Faraò Trio on Spotify',
#  'image': 'https://i.scdn.co/image/71c38c94c466ea5ddce8a9730ac8b72e14db74af',
#  'thumbnail': 'https://tse4.mm.bing.net/th?id=OIP._Fz8hWDXYOEAnXq8d_4LTgHaHa&pid=Api',
#  'url': 'https://open.spotify.com/artist/58dTi4Xr0bd6yd8XKgimAr',
#  'height': 640, 'width': 640, 'source': 'Bing'}

# image.resize((int(1391/1.7),int(2048/1.7))).save('/home/dima/tmp/img2.jpg')

def get_images(query):
    global prev_query, IMAGES_GEN
    if prev_query != query:
        # print(f" ===> QUERY: {query}")
        with DDGS() as ddgs:
            IMAGES_GEN = (i['image'] for i in ddgs.images(query, max_results=IMAGES_MAX_RESULTS))
        prev_query = query
    # results = ddg_images(query, max_results=1)
    # print(f"results[0]['image']: {results[0]['image']}")
    # return results[0]['image'] if results else None
    return next(IMAGES_GEN)

def get_images2(query):
    global prev_query, IMAGES_GEN
    img_data = None

    while True:
        try:
            img_data = next(IMAGES_GEN)
        except Exception as e:
            pass

        # print(f" IMG_DATA: {img_data}")

        if prev_query != query or img_data == None:
            print(f"  📡  GET NEW IMAGES from internet\n  img_data:{img_data}\n  prev_query:{prev_query}, query:{query}")
            with DDGS(proxy=PROXY) as ddgs:
                try:
                    IMAGES_GEN = ddgs.images(f'musicians performer "{query}" live concert',
                                             max_results=IMAGES_MAX_RESULTS).__iter__()
                except Exception as e:
                    print(f" ⚠️  DDGS: {e}")
                    print(f" 👉  Current IP: {tor_get_proxy_ip()}")
                    tor_renew_ip()
                    print(f" 👉  New IP    : {tor_get_proxy_ip()}")
                    break
            # print(f"IMAGES_GEN: {IMAGES_GEN}")
            shutil.rmtree(IMAGE_FOLDER, ignore_errors=True)
            os.makedirs(IMAGE_FOLDER)
            prev_query = query
            continue
        
        min_size = min(img_data['height'],img_data['width'])
        if min_size < IMAGE_MINIMAL_SIZE:
            # print(f" * MIN_SIZE: {min_size}")
            continue

        url = img_data['image']  

        # download image
        response = requests.get(url)
        if response.ok == False:
            continue
        image = Image.open(BytesIO(response.content))
        image_ext = image.format.lower()
        # img_name = f"{os.path.basename(url)}.{image_ext}"
        img_name = f"artist_{datetime.datetime.now().microsecond}.{image_ext}"
        img_path = f"{IMAGE_FOLDER}/{img_name}"

        # for resize
        scaling_factor = image.height/DISPLAY_HIGH
        if scaling_factor != 0:
            image = image.resize((int(image.width/scaling_factor),
                                  int(image.height/scaling_factor)))
        
        # image.save(image_name, format="JPEG")
        image.save(f"{img_path}", format=image.format)
        return img_name

@app.route('/')
def index():
    print(f" ============= INDEX ===============")
    return render_template_string(TEMPLATE)


@app.route('/image')
def get_image():
    # query = f"""artist wiki "{mpd_get_albumartist()}" """
    query = mpd_get_albumartist()
    print(f" 🔵 MPD_CURRENT_SONG_ARTIST: '{query}'")

    filename = get_images2(query)  # Поиск изображений по ключевому слову

    if filename:
        return jsonify({"filename": filename})
    return jsonify({"filename": ""})


@app.route('/static_image/<filename>')
def static_image(filename):
    return send_from_directory(IMAGE_FOLDER, filename)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)
    #app.run(host='localhost', port=5000, debug=False)

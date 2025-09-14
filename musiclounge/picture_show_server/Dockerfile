#### MPD pictures show server

# 07.09.25

# FROM python:alpine
FROM python:3.12-alpine
WORKDIR /app
RUN pip install --upgrade pip && pip install flask Pillow ddgs python-mpd2 requests[socks] stem
EXPOSE 5000
COPY show_imgs_server.py .
ENTRYPOINT ["python"]
CMD ["show_imgs_server.py"]

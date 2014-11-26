#!/bin/bash
# Self signed web scoreboard certificate
#
#openssl req -sha256 -out scoreboard-web-ssl.csr -new -newkey rsa:2048 -nodes -keyout scoreboard-web-ssl.key -days 365
#openssl x509 -req -days 365 -in scoreboard-web-ssl.csr -signkey scoreboard-web-ssl.key -out scoreboard-web-ssl.crt

# For postgresql
#openssl req -x509 -nodes -days 365 -newkey rsa:4096 -keyout postgres-server.key -out postgres-server.crt

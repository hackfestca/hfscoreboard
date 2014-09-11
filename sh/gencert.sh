#!/bin/bash
openssl req -x509 -newkey rsa:2048 -keyout certs/key.pem -nodes -out certs/cert.pem -days 5

#openssl req -x509 -nodes -days 365 -newkey rsa:4096 -keyout postgres-server.key -out postgres-server.crt

#!/bin/bash
openssl req -x509 -newkey rsa:2048 -keyout certs/key.pem -nodes -out certs/cert.pem -days 5

#!/bin/sh

# Old way
#pg_dump -a --compress=9 -f ../backups/scoreboard-$(date '+%Y-%m-%d-%H%M%S').sql.gz "sslmode=require host=db.hf dbname=scoreboard user=owner sslcert=../certs/hf.cli.db.owner.crt sslkey=../certs/hf.cli.db.owner.key"

# HF2k17 way
pg_dump -a --compress=9 -f ./backups/scoreboard-$(date '+%Y-%m-%d-%H%M%S').sql.gz scoreboard

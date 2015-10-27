#!/bin/sh
pg_dump -a --compress=9 -f ./backups/scoreboard-$(date '+%Y-%m-%d-%H%M%S').sql.gz "sslmode=require host=scoreboard.hf dbname=scoreboard user=owner sslcert=../certs/hf.cli.db.owner.crt sslkey=../certs/hf.cli.db.owner.key"

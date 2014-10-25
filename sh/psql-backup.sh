#!/bin/bash
pg_dump -a -f /home/scoreboard.bkp/scoreboard-$(date '+%Y-%M-%d-%H%M%S').sql "sslmode=require host=db.hf dbname=scoreboard user=hfowner sslcert=../certs/cli.psql.scoreboard.hfowner.crt sslkey=../certs/cli.psql.scoreboard.hfowner.key"


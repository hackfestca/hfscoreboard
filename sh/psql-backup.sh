#!/bin/ksh
pg_dump -a --compress=9 -f /home/mon2k14/scoreboard.bkp/scoreboard-$(date '+%Y-%m-%d-%H%M%S').sql.gz "sslmode=require host=db.hf dbname=scoreboard user=hfowner sslcert=../certs/cli.psql.scoreboard.hfowner.crt sslkey=../certs/cli.psql.scoreboard.hfowner.key"

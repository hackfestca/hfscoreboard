#!/bin/bash
psql "sslmode=require host=db.hf dbname=scoreboard user=hfowner sslcert=../certs/cli.psql.scoreboard.hfowner.crt sslkey=../certs/cli.psql.scoreboard.hfowner.key"

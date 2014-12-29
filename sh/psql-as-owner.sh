#!/bin/bash
psql "sslmode=require host=db.hf dbname=scoreboard user=owner sslcert=../certs/cli.psql.scoreboard.owner.crt sslkey=../certs/cli.psql.scoreboard.owner.key"

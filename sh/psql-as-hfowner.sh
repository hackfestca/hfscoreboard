#!/bin/bash
psql "sslmode=require host=scoreboard.hf dbname=scoreboard user=hfowner sslcert=../certs/cli.psql.mon2k14.crt sslkey=../certs/cli.psql.mon2k14.key"

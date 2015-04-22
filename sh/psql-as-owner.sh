#!/bin/bash
psql "sslmode=require host=db.hf dbname=scoreboard user=owner sslcert=../certs/hf.cli.db.owner.crt sslkey=../certs/hf.cli.db.owner.key"

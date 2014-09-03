#!/bin/bash
psql "sslmode=require host=mon2k14.hf dbname=mon2k14 user=hfowner sslcert=../certs/cli.psql.mon2k14.crt sslkey=../certs/cli.psql.mon2k14.key"

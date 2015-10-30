#!/usr/bin/env python3
# -*- coding: utf-8 -*-

'''
This script is used for massive interactions with database (flag imports, team imports, functions updates, 
table creations, apply security, etc.)

@author: Martin Dubé
@organization: Hackfest Communications
@license: Modified BSD License
@contact: martin.dube@hackfest.ca

Copyright (c) 2014, Hackfest Communications
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of the <organization> nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
'''

# Python version validation
import sys
if sys.version_info < (3,2,0):
    print('Python version 3.2 or later is needed for this script')
    exit(1);

sys.path.insert(0, 'lib')
del sys

# Project imports
import config
from lib import InitController

# System imports
import argparse
import psycopg2

# Get args
usage = 'usage: %prog action [options]'
description = 'HF Scoreboard database initialization script. Use this tool to create db structure, apply security and import data'
parser = argparse.ArgumentParser(description=description)
parser.add_argument('-v','--version', action='version', version='%(prog)s 1.1 (2015-11-07)')
parser.add_argument('--debug', action='store_true', dest='debug', default=False, \
                    help='Run the tool in debug mode')

actGrp = parser.add_argument_group("Action", "Select one of these action")
actGrp.add_argument('--tables','-t', action='store_true', dest='tables', default=False, \
              help='Import structure only (tables and functions)')
actGrp.add_argument('--functions','-f', action='store_true', dest='functions', default=False, \
              help='Import structure only (tables and functions)')
actGrp.add_argument('--data','-d', action='store_true', dest='data', default=False, \
              help='Import data only')
actGrp.add_argument('--flags','-l', action='store_true', dest='flags', default=False, \
              help='Import flags only (from csv file: import/flags.csv)')
actGrp.add_argument('--teams','-e', action='store_true', dest='teams', default=False, \
              help='Import teams only (from csv file: import/teams.csv)')
actGrp.add_argument('--black-market','-b', action='store_true', dest='blackmarket', default=False, \
              help='Import black market items (from csv file: import/blackmarket.csv)')
actGrp.add_argument('--security','-s', action='store_true', dest='security', default=False, \
              help='Import security only')
actGrp.add_argument('--all', '-a', action='store_true', dest='all', default=False, \
              help='Import all')

args = parser.parse_args()

if args.debug:
    print('[-] Arguments: ' + str(args))

# Step 1: Connect to database
try:
    c = InitController.InitController()
    c.setDebug(args.debug)
except psycopg2.Error as e:
    print(e)
    exit(1)
except Exception as e:
    print(e)
    exit(1)

# Step 2: Process user request
try:
    if args.tables:
        print('Importing table structure')
        c.importTables()
    elif args.functions:
        print('Importing functions / stored procedure')
        c.importFunctions()
    elif args.data:
        print('Importing data')
        c.importData()
    elif args.flags:
        print('Importing flags')
        c.importFlags()
    elif args.teams:
        print('Importing teams')
        c.importTeams()
    elif args.blackmarket:
        print('Importing black market items')
        c.importBlackMarketItems()
    elif args.security:
        print('Importing database security')
        c.importSecurity()
    elif args.all:
        print('Importing all (struct + data + security)')
        c.importAll()
    else:
        parser.print_help()
except psycopg2.Warning as e:
    print('[-] ' + str(e))
except psycopg2.Error as e:
    print('[-] ' + str(e))
#except Exception as e:
#    print(e)
else:
    if args.debug:
        print('[+] Import successful')

c.close()


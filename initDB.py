#!/usr/bin/python3
# -*- coding: utf-8 -*-

'''
This script is the main interface for admins to manage CTF

@author: Martin Dubé
@organization: Hackfest Communications
@license: GNU GENERAL PUBLIC LICENSE Version 3
@contact: martin.dube@hackfest.ca

    Copyright (C) 2014  Martin Dubé

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
'''

# Python version validation
import sys
if sys.version_info < (3,2,0):
    print('Python version 3.2 or later is needed for this script')
    exit(1);

# Should be used only for admin side
sys.path.insert(0, 'lib')
del sys

# Project imports
import config
from lib import kothOwner

# System imports
import logging
import postgresql.exceptions
import argparse

# Some vars and constants
VERSION = '0.01'
DEBUG = True

# Get args
usage = 'usage: %prog action [options]'
description = 'King of the Hill DB init script. Use this tool to manipulate db structure, update security and import data'
parser = argparse.ArgumentParser(description=description)

actGrp = parser.add_argument_group("Action", "Select one of these action")

actGrp.add_argument('--tables','-t', action='store_true', dest='tables', default=False, \
              help='Import structure only (tables and functions)')
actGrp.add_argument('--functions','-f', action='store_true', dest='functions', default=False, \
              help='Import structure only (tables and functions)')
actGrp.add_argument('--data','-d', action='store_true', dest='data', default=False, \
              help='Import data only')
actGrp.add_argument('--flags','-l', action='store_true', dest='flags', default=False, \
              help='Import flags only (from csv file: flags.csv)')
actGrp.add_argument('--teams','-e', action='store_true', dest='teams', default=False, \
              help='Import teams only (from csv file: teams.csv)')
actGrp.add_argument('--security','-s', action='store_true', dest='security', default=False, \
              help='Import security only')
actGrp.add_argument('--all', '-a', action='store_true', dest='all', default=False, \
              help='Import all')
actGrp.add_argument('--version', '-v', action='store_true', dest='version', default=False, \
              help='Display client version')

args = parser.parse_args()

# Validate args
if  not args.tables and \
    not args.functions and \
    not args.data and \
    not args.flags and \
    not args.teams and \
    not args.security and \
    not args.all and \
    not args.version:
    print('[-] You must specify an action')
    exit(1)

# DB Connect
try:
    c = kothOwner.kothOwner()
    c.setDebug(DEBUG)
except postgresql.exceptions.PLPGSQLRaiseError as e:
    print('[-] ('+str(e.code)+') '+e.message)
    exit(1)
except postgresql.exceptions.ClientCannotConnectError as e:
    print('[-] Insufficient privileges to connect to database')
    print(e)
    exit(1);
except postgresql.exceptions.InsecurityError:
    print('[-] Something insecure was detected. Please contact an admin')
    print(e)
    exit(1);
#except Exception as e:
#    print(e)


# Run requested action
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
    elif args.security:
        print('Importing database security')
        c.importSecurity()
    elif args.all:
        print('Importing all (struct + data + security)')
        c.importAll()
    elif args.version:
        print('client.py is v'+VERSION+', kothOwner.py is v'+c.getVersion())
#except postgresql.exceptions.PLPGSQLRaiseError as e:
#    print('[-] ('+str(e.code)+') '+e.message)
except postgresql.exceptions.InsufficientPrivilegeError:
    print('[-] Insufficient privileges')
except postgresql.exceptions.UniqueError:
    print('[-] Flag already submitted')
except postgresql.exceptions.UndefinedFunctionError:
    print('[-] The specified function does not exist. Please contact an admin')
except IOError as e:
    print('[-] '+str(e))
except postgresql.message.Message as e:
    print(e)
#except Exception as e:
#    print(e)
#    dump(e)
else:
    print('[+] Import successful')

c.close()




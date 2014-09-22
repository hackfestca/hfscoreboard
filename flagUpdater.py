#!/usr/bin/python3
# -*- coding: utf-8 -*-

'''
This script reads the koth database and update all relevant flags

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
from lib import kothUpdater

# System imports
import logging
import postgresql.exceptions
import argparse

# Some vars and constants
VERSION = '0.01'
DEBUG = True

# Get args
usage = 'usage: %prog action [options]'
description = 'King of the Hill flag updater. Use this tool to update flags on koth boxes'
parser = argparse.ArgumentParser(description=description)

actGrp = parser.add_argument_group("Action", "Select one of these action")
optGrp = parser.add_argument_group("Option", "Use any depending on choosen action")

actGrp.add_argument('--all', '-a', action='store_true', dest='all', default=False, \
              help='Update all system flags')
actGrp.add_argument('--host',  action='store', dest='host', default='',\
              type=str, help='Update all flags of a specific box')
actGrp.add_argument('--name', '-n',  action='store', dest='name', default='',\
              type=str, help='Update a specific flag from name')
actGrp.add_argument('--list', '-l',  action='store_true', dest='list', default=False,\
              help='List flags that will be processed')
actGrp.add_argument('--version', '-v', action='store_true', dest='version', default=False, \
              help='Display client version')

args = parser.parse_args()

# Validate args
if args.all and \
    not args.host == '' and \
    not args.name == '' and \
    not args.list and \
    not args.version:
    print('[-] You must specify an action')
    exit(1)

# DB Connect
try:
    c = kothUpdater.kothUpdater()
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
#    print(dir(e))
#    print(e.args)
#    print(type(e))
#    exit(1)

c.setDebug(DEBUG)

# Run requested action
try:
    if args.all:
        print("Updating all system flags")
        ret = c.updateAllFlags()
    elif args.host != '':
        print('Updating all flags on host "' + args.host + '"')
        ret = c.updateFlagsFromHost(args.host)
    elif args.name != '':
        print("Updating the following flag: %s" % args.name)
        ret = c.updateFlagFromName(args.name)
    elif args.list:
        print("Listing flags")
        print(c.getFormatKingFlags())
    elif args.version:
        print('client.py is v'+VERSION+', kothUpdater.py is v'+c.getVersion())
except postgresql.exceptions.InsufficientPrivilegeError:
    print('[-] Insufficient privileges')
except postgresql.exceptions.UndefinedFunctionError:
    print('[-] The specified function does not exist. Please contact an admin')
#except Exception as e:
#    print(e)
else:
    print('[+] End of update')

c.close()



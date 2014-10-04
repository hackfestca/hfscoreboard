#!/usr/bin/python3
# -*- coding: utf-8 -*-

'''
This script is the main interface for players to submit flags and display score

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
from lib import kothClient

# System imports
import logging
import postgresql.exceptions
import argparse

# Some vars and constants
VERSION = '0.03'
DEBUG = True

# Some functions
def dump(obj):
    for attr in dir(obj):
        print("obj.%s = %s" % (attr, getattr(obj, attr)))

# Get args
usage = 'usage: %prog action [options]'
description = 'King of the Hill player client. Use this tool to submit flags and display score'
parser = argparse.ArgumentParser(description=description)

actGrp = parser.add_argument_group("Action", "Select one of these action")
optGrp = parser.add_argument_group("Option", "Use any depending on choosen action")

actGrp.add_argument('--submit', '-s',  action='store', dest='flag', default='',\
              type=str, help='Submit a flag')
actGrp.add_argument('--score', action='store_true', dest='score', default=False, \
              help='Display score')
actGrp.add_argument('--catProg', '-c', action='store_true', dest='catProgress', default=False, \
              help='Display category progression')
actGrp.add_argument('--flagProg', '-f', action='store_true', dest='flagProgress', default=False, \
              help='Display flag progression')
actGrp.add_argument('--submitRandom', '-r', action='store_true', dest='submitRandom', 
              default=False, help='Submit a random flag (for dev purpose)')
actGrp.add_argument('--news', '-n', action='store_true', dest='news', 
              default=False, help='Display news')
actGrp.add_argument('--info', '-i', action='store_true', dest='info', 
              default=False, help='Display team information')
actGrp.add_argument('--version', '-v', action='store_true', dest='version', default=False, \
              help='Display client version')

optGrp.add_argument('--top', '-t', action='store', dest='top', default=config.KOTH_DEFAULT_TOP_VALUE, \
              type=int, help='Limit --score number of result')
optGrp.add_argument('--cat', action='store', dest='cat', default=None, \
              type=str, help='Print results only for this category name')
args = parser.parse_args()

# Validate args
if args.flag == '' and \
    not args.score and \
    not args.catProgress and \
    not args.flagProgress and \
    not args.submitRandom and \
    not args.news and \
    not args.info and \
    not args.version:
    print('[-] You must specify an action (Try to add -h)')
    exit(1)

# DB Connect
try:
    c = kothClient.kothClient()
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
except Exception as e:
    print(e)
    dump(e)
    exit(1)


# Run requested action
try:
    if args.flag != '':
        print("Submitting flag")
        pts = c.submitFlag(args.flag)
    elif args.score:
        print('Displaying score')
        print(c.getFormatScore(args.top,None,args.cat))
    elif args.catProgress:
        print('Displaying category progression')
        print(c.getFormatCatProgress())
    elif args.flagProgress:
        print('Displaying category progression')
        print(c.getFormatFlagProgress())
    elif args.submitRandom:
        print("Submitting random flag")
        pts = c.submitRandomFlag()
    elif args.news:
        print("Displaying news")
        print(c.getFormatValidNews())
    elif args.info:
        print("Displaying team informations")
        print(c.getFormatTeamInfo())
    elif args.version:
        print('client.py is v'+VERSION+', kothClient.py is v'+c.getVersion())
except postgresql.exceptions.PLPGSQLRaiseError as e:
    print('[-] ('+str(e.code)+') '+e.message)
except postgresql.exceptions.InsufficientPrivilegeError:
    print('[-] Insufficient privileges')
except postgresql.exceptions.UniqueError:
    print('[-] Flag already submitted')
except postgresql.exceptions.StringRightTruncationError as e:
    print('[-] Input is too big ('+e.message+')')
except postgresql.exceptions.UndefinedFunctionError:
    print('[-] The specified function does not exist. Please contact an admin')
except postgresql.message.Message as m:
    print(m)
except Exception as e:
    print(e)
    dump(e)
else:
    if args.flag != '':
        print('[+] Flag successfuly submitted ('+str(pts)+' pts)')
    elif args.score:
        print('[+] Score successfuly displayed')
    elif args.catProgress:
        print('[+] Score successfuly displayed')
    elif args.flagProgress:
        print('[+] Score successfuly displayed')
    elif args.submitRandom:
        print('[+] Flag successfuly submitted ('+str(pts)+' pts)')
    elif args.news:
        print('[+] News sucessfuly displayed')
    elif args.info:
        print('[+] Team info sucessfuly displayed')

c.close()


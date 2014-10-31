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
from lib import kothPlayer

# System imports
import logging
import argparse
import socket
from xmlrpc.client import Fault

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
actGrp.add_argument('--news', '-n', action='store_true', dest='news', 
              default=False, help='Display news')
actGrp.add_argument('--info', '-i', action='store_true', dest='info', 
              default=False, help='Display team information')

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
    not args.news and \
    not args.info:
    print('[-] You must specify an action (Try to add -h)')
    exit(1)

# DB Connect
try:
    c = kothPlayer.kothPlayer()
except Exception as e:
    print(e)
    exit(1)

# Run requested action
try:
    if args.flag != '':
        print("Submitting flag")
        pts = c.submitFlag(args.flag)
    elif args.score:
        print('Displaying score')
        print(c.getScore(args.top,None,args.cat))
    elif args.catProgress:
        print('Displaying category progression')
        print(c.getCatProgress())
    elif args.flagProgress:
        print('Displaying flag progression')
        print(c.getFlagProgress())
    elif args.news:
        print("Displaying news")
        print(c.getNews())
    elif args.info:
        print("Displaying team informations")
        print(c.getTeamInfo())

except socket.error as e:
    print('[-] %s' % e)
except Fault as err:
    print('[-] %s' % err.faultString)
else:
    if args.flag != '':
        print('[+] Flag successfuly submitted ('+str(pts)+' pts)')
    elif args.score:
        print('[+] Score successfuly displayed')
    elif args.catProgress:
        print('[+] Score successfuly displayed')
    elif args.flagProgress:
        print('[+] Score successfuly displayed')
    elif args.news:
        print('[+] News sucessfuly displayed')
    elif args.info:
        print('[+] Team info sucessfuly displayed')

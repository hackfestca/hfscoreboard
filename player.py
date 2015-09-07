#!/usr/bin/python3
# -*- coding: utf-8 -*-

'''
This script is the main interface for players to submit flags and display score

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
from lib import PlayerController

# System imports
import argparse
import socket
from xmlrpc.client import Fault

# Get args
usage = 'usage: %prog action [options]'
description = 'HF Scoreboard player client. Use this tool to submit flags and display score'
parser = argparse.ArgumentParser(description=description)
parser.add_argument('-v','--version', action='version', version='%(prog)s 1.0 (2014-11-25)')
parser.add_argument('--debug', action='store_true', dest='debug', default=False, \
                    help='Run the tool in debug mode')

actGrp = parser.add_argument_group("Action", "Select one of these action")
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

optGrp = parser.add_argument_group("Option", "Use any depending on choosen action")
optGrp.add_argument('--top', '-t', action='store', dest='top', default=config.DEFAULT_TOP_VALUE, \
              type=int, help='Limit --score number of rows')
optGrp.add_argument('--cat', action='store', dest='cat', default=None, \
              type=str, help='Print results only for this category name')

args = parser.parse_args()

# Step 1: Connect to API
try:
    c = PlayerController.PlayerController()
except Exception as e:
    print(e)
    exit(1)

# Step 2: Process user request
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
    else:
        parser.print_help()
except socket.error as e:
    print('[-] %s' % e)
except Fault as err:
    print('[-] %s' % err.faultString)
else:
    if args.debug:
        print('[+] Job completed')


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
from lib import kothRPC

# System imports
import logging
import argparse
from xmlrpc.server import SimpleXMLRPCServer

# Some vars and constants
VERSION = '0.03'
DEBUG = True
HOST = '0.0.0.0'
PORT = 8000

# Get args
usage = 'usage: %prog action [options]'
description = 'King of the Hill player rpc api. Start this service to enable the use of player.py.'
parser = argparse.ArgumentParser(description=description)

actGrp = parser.add_argument_group("Action", "Select one of these action")

actGrp.add_argument('--start', '-s',  action='store_true', dest='start', default=False,\
              help='Start the service')
args = parser.parse_args()

# Validate args
if not args.start: 
    print('[-] You must specify an action (Try to add -h)')
    exit(1)

# Run requested action
if args.start:
    print("Starting rpc server")
    server = SimpleXMLRPCServer((HOST,PORT),requestHandler=kothRPC.rpcHandler,allow_none=True)
    try:
        server.serve_forever()
    except Exception as e:
        print(e)
    except KeyboardInterrupt:
        exit(0)

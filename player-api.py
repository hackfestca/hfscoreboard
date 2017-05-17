#!/usr/local/bin/python3
# -*- coding: utf-8 -*-

'''
This script is the XML RPC script for player.py interactions with the scoreboard.

@author: Martin Dubé
@organization: Hackfest Communications
@license: Modified BSD License
@contact: martin.dube@hackfest.ca

Copyright (c) 2015, Hackfest Communications
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

# Project imports
import config
from lib import RPCController

# System imports
import argparse
from xmlrpc.server import SimpleXMLRPCServer
from xmlrpc.client import Marshaller
from decimal import Decimal

def dump_decimal(self, value, write):
    write("<value><double>")
    write(str(value))
    write("</double></value>\n")
Marshaller.dispatch[Decimal] = dump_decimal

# Get args
usage = 'usage: %prog action [options]'
description = 'HF Scoreboard player xml rpc api. Start this script to enable the use of player.py.'
parser = argparse.ArgumentParser(description=description)
parser.add_argument('-v','--version', action='version', version='%(prog)s 1.1 (2014-11-07)')
parser.add_argument('--debug', action='store_true', dest='debug', default=False, \
                    help='Run the tool in debug mode')
parser.add_argument('--behind-proxy', action='store_true', dest='behindProxy', default=False, \
                    help='Run the api behind a proxy. It will use X-Real-IP or X-Forwarded-For headers to identify players instead of client IP.')

actGrp = parser.add_argument_group("Action", "Select one of these action")
actGrp.add_argument('--start', '-s',  action='store_true', dest='start', default=False,\
              help='Start the service')
args = parser.parse_args()

# Run requested action
if args.start:
    rh = RPCController.RPCHandler
    rh.behindProxy = args.behindProxy
    if sys.version_info >= (3,4,0):
        server = SimpleXMLRPCServer((config.PLAYER_API_LISTEN_ADDR,config.PLAYER_API_LISTEN_PORT),requestHandler=rh,allow_none=True,logRequests=True,use_builtin_types=True)
    else:
        server = SimpleXMLRPCServer((config.PLAYER_API_LISTEN_ADDR,config.PLAYER_API_LISTEN_PORT),requestHandler=rh,allow_none=True,logRequests=True)

    print("RPC server started.")
    try:
        server.serve_forever()
    except Exception as e:
        print(e)
    except KeyboardInterrupt:
        exit(0)
else:
    parser.print_help()

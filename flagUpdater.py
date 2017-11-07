#!/usr/bin/env python3
# -*- coding: utf-8 -*-

'''
This script reads the database and upload new flags to KOTH servers.

@author: Martin Dubé
@organization: Hackfest Communications
@license: Modified BSD License
@contact: martin.dube@hackfest.ca

Copyright (c) 2017, Hackfest Communications
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

# Should be used only for admin side
sys.path.insert(0, 'lib')
del sys

# Project imports
import config
from lib import FlagUpdaterController

# System imports
import argparse
import psycopg2

# Get args
usage = 'usage: %prog action [options]'
description = 'HF Scoreboard flag updater. Use this tool to update flags on koth boxes'
parser = argparse.ArgumentParser(description=description)
parser.add_argument('-v','--version', action='version', version='%(prog)s 1.1 (2017-11-07)')
parser.add_argument('--debug', action='store_true', dest='debug', default=False, \
                    help='Run the tool in debug mode')

actGrp = parser.add_argument_group("Action", "Select one of these action")
actGrp.add_argument('--all', '-a', action='store_true', dest='all', default=False, \
              help='Update all system flags')
actGrp.add_argument('--host',  action='store', dest='host', default='',\
              type=str, help='Update all flags of a specific box')
actGrp.add_argument('--name', '-n',  action='store', dest='name', default='',\
              type=str, help='Update a specific flag from name')
actGrp.add_argument('--list', '-l',  action='store_true', dest='list', default=False,\
              help='List flags that will be processed')

args = parser.parse_args()

# Step 1: Connect to database
try:
    c = FlagUpdaterController.FlagUpdaterController()
except psycopg2.Warning as e:
    print('[-] ' + str(e))
except psycopg2.Error as e:
    print('[-] ' + str(e))
    exit(1)
except Exception as e:
    print(e)
    exit(1)

c.setDebug(args.debug)

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
    else:
        parser.print_help()
except KeyboardInterrupt:
    print("Bye")
    sys.exit()
except ValueError:
    print('[-] Invalid input. Please RTFM')
except AssertionError as e:
    print('[-] Assertion error: %s' % e.args)
except psycopg2.Warning as e:
    print('[-] ' + str(e))
except psycopg2.Error as e:
    print('[-] ' + str(e))
except Exception as e:
    print(e)
else:
    if args.debug:
        print('[+] End of update')

c.close()


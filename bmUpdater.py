#!/usr/bin/env python3
# -*- coding: utf-8 -*-

'''
This script reads the database and update the black market by updating status and uploading files on the front-end.

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

# Should be used only for admin side
sys.path.insert(0, 'lib')
del sys

# Project imports
import config
from lib import BMUpdaterController

# System imports
import argparse
import psycopg2

# Get args
usage = 'usage: %prog action [options]'
description = 'HF Scoreboard black market updater. Use this tool to update black market items and make them available from the scoreboard'
parser = argparse.ArgumentParser(description=description)
parser.add_argument('-v','--version', action='version', version='%(prog)s 1.0 (2014-11-25)')
parser.add_argument('--debug', action='store_true', dest='debug', default=False, \
                    help='Run the tool in debug mode')

actGrp = parser.add_argument_group("Action", "Select one of these action")
actGrp.add_argument('--updateForApproval', '-p', action='store_true', dest='updateForApproval', default=False, \
              help='Update all items that have status "For Approval"')
actGrp.add_argument('--updateToRetrieve', '-r', action='store_true', dest='updateToRetrieve', default=False, \
              help='Update all items that have status "Ready to retrieve"')
actGrp.add_argument('--updateToPublish', '-u', action='store_true', dest='updateToPublish', default=False, \
              help='Update all items that have status "Ready to publish"')
actGrp.add_argument('--updateSold', '-s', action='store_true', dest='updateSold', default=False, \
              help='Update all items that have status "Sold" (Remove them from frontend)')
actGrp.add_argument('--updateAll', '-a', action='store_true', dest='updateAll', default=False, \
              help='Update all items (even already existing ones)')
actGrp.add_argument('--deleteAll', '-d', action='store_true', dest='deleteAll', default=False, \
              help='Delete all items (Dangerous! Will erase all files in black market folder)')
actGrp.add_argument('--list', '-l',  action='store_true', dest='list', default=False,\
              help='List flags that will be processed')

args = parser.parse_args()

# Step 1: Connect to database
try:
    c = BMUpdaterController.BMUpdaterController()
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
    if args.updateForApproval:
        print('Updating black market items with status "For Approval"')
        ret = c.updateForApproval()
    elif args.updateToRetrieve:
        print('Updating black market items with status "Ready to retrieve"')
        ret = c.updateToRetrieve()
    elif args.updateToPublish:
        print('Updating black market items with status "Ready to publish"')
        ret = c.updateToPublish()
    elif args.updateSold:
        print('Updating black market items with status "Sold"')
        ret = c.updateSold()
    elif args.updateAll:
        print('Updating all black market items')
        ret = c.updateAll()
    elif args.deleteAll:
        print('Delete all black market items')
        ret = c.deleteAll()
    elif args.list:
        print("Listing black market items")
        print(c.getFormatBMItems())
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
#except Exception as e:
#    print(e)
else:
    if args.debug:
        print('[+] End of update')

c.close()


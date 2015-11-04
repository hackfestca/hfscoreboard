#!/usr/bin/env python3
# -*- coding: utf-8 -*-

'''
This script is the main interface for players to submit flags and display score

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

# System imports
import argparse
import socket
import os.path
from xmlrpc.client import Fault,ProtocolError,Binary,ServerProxy
from urllib.request import Request, urlopen, HTTPSHandler, build_opener
from urllib.error import URLError, HTTPError
from urllib.parse import urlparse
from time import sleep
from datetime import datetime
import ssl

class PlayerController():
    """
    Player controller class used by player.py
    """
    _oRPC = None

    def __init__(self):
        # Setup SSL context
        if sys.version_info >= (3,4,0) and config.PLAYER_API_URI.startswith('https'):
            context = ssl.SSLContext(ssl.PROTOCOL_TLSv1_2)
            context.verify_mode = ssl.CERT_REQUIRED
            context.check_hostname = True
            #context.load_default_certs()       # To use installed CAs on the machine
            context.load_verify_locations(config.PLAYER_API_SSL_ROOT_CA)
        else:
            context = None

        if sys.version_info >= (3,4,0):
            self._oRPC = ServerProxy(config.PLAYER_API_URI,allow_none=True,use_builtin_types=True,context=context)
        else:
            self._oRPC = ServerProxy(config.PLAYER_API_URI_OLD,allow_none=True,use_datetime=True)

    def submitFlag(self,flagValue):
        return self._oRPC.submitFlag(flagValue)

    def getScore(self,top=config.DEFAULT_TOP_VALUE,ts=None,cat=None):
        return self._oRPC.getScore(top,ts,cat)

    def buyBMItem(self,bmItemId):
        return self._oRPC.buyBMItem(bmItemId)

    def sellBMItem(self,name,amount,qty,desc,data):
        return self._oRPC.sellBMItem(name,amount,qty,desc,data)

    def getBMItemInfo(self,bmItemId):
        return self._oRPC.getBMItemInfo(bmItemId)

    def getBMItemLink(self,bmItemId):
        return self._oRPC.getBMItemLink(bmItemId)

    def getBMItemData(self,bmItemId):
        return self._oRPC.getBMItemData(bmItemId)

    def getBMItemList(self,top):
        return self._oRPC.getBMItemList(top)

    def getBMItemCategoryList(self):
        return self._oRPC.getBMItemCategoryList()

    def getBMItemStatusList(self):
        return self._oRPC.getBMItemStatusList()

    def buyLoto(self,amount):
        return self._oRPC.buyLoto(amount)

    def getLotoHistory(self,top):
        return self._oRPC.getLotoHistory(top)

    def getLotoInfo(self):
        return self._oRPC.getLotoInfo()

    def getCatProgress(self):
        return str(self._oRPC.getCatProgress())

    def getFlagProgress(self):
        return str(self._oRPC.getFlagProgress())

    def getNews(self):
        return self._oRPC.getNews()

    def getTeamInfo(self):
        return self._oRPC.getTeamInfo()

    def getTeamSecrets(self):
        return self._oRPC.getTeamSecrets()

    def getEvents(self,lastUpdate=None,facility=None,severity=None,grep=None,top=300):
        return self._oRPC.getEvents(lastUpdate,facility,severity,grep,top)

    def getLogEvents(self,lastUpdate=None,facility=None,severity=None,grep=None,top=300):
        return self._oRPC.getLogEvents(lastUpdate,facility,severity,grep,top)

    def printLiveEvents(self,lastUpdate=None,facility=None,severity=None,grep=None,top=300,refresh=10):
        events = self.getLogEvents(lastUpdate,facility,severity,grep,top)
        print(events)
        lastUpdate = datetime.now()
        sleep(refresh)

        while True:
            events = self.getLogEvents(lastUpdate,facility,severity,grep,top)
            if len(events) > 0:
                print(events)
                lastUpdate = datetime.now()
            sleep(refresh)


# Get args
usage = 'usage: %prog action [options]'
description = 'HF Scoreboard player client. Use this tool to submit flags, display score, buy loto tickets and use the black market.'
parser = argparse.ArgumentParser(description=description)
parser.add_argument('-v','--version', action='version', version='%(prog)s 1.1 (2015-11-07)')
parser.add_argument('--debug', action='store_true', dest='debug', default=False, \
                    help='Run the tool in debug mode')
subparsers = parser.add_subparsers(dest='action')

psubmit = subparsers.add_parser('submit', help='Submit a flag')
psubmit.add_argument('flag', type=str,\
                     metavar='FLAG', help='Flag to submit.')

pscore = subparsers.add_parser('score', help='Display score')

pbmDesc = '''\
variables:
    ID          int - Item id. 
    NAME        str - Name of the item. Make it short and sweet.
    DESC        str - Description of the item. Make it teasy!
    PATH        str - Path to the file to be uploaded. All format are supported.
    AMOUNT      float - Cost of the item. Cannot be < 0.
    QTY         int - (optional) Max number of time the item can get bought. Cannot be < 0. Default = 0 (no limit).
'''
pbmEpi = '''\
examples:
    --buy 5

    --sell 'Track 1 leak|Buying this item is like buying a glass of scotch, you will simply enjoy.|/home/martin/track1.zip|5000'    # without qty
    --sell 'Track 1 leak|Buying this item is like buying a glass of scotch, you will simply enjoy.|/home/martin/track1.zip|5000|2'  # with qty
'''
pbm = subparsers.add_parser('bm', description=pbmDesc, epilog=pbmEpi,\
                            formatter_class=argparse.RawDescriptionHelpFormatter,\
                            help='Manage black market items')
pbm_a = pbm.add_argument_group("action")
pbm_o = pbm.add_argument_group("option")
pbm_a.add_argument('--buy', action='store', dest='buy', default='', metavar='\'ID\'', \
                   help='Buy an item.')
pbm_a.add_argument('--sell', action='store', dest='sell', default='', type=str, metavar='\'NAME|DESC|PATH|AMOUNT|QTY\'', \
                   help='Sell an item on the black market.')
pbm_a.add_argument('--info', action='store', dest='info', default='', metavar='\'ID\'', \
                   help='Show an item information.')
pbm_a.add_argument('--get', action='store', dest='get', default='', metavar='\'ID\'', \
                   help='Download an item.')
pbm_a.add_argument('--list', '-l', action='store_true', dest='list', default=False, help='List black market items.')
pbm_a.add_argument('--list-categories', action='store_true', dest='listCategories', default=False, help='List item categories.')
pbm_a.add_argument('--list-status', action='store_true', dest='listStatus', default=False, help='List item status.')

ploto = subparsers.add_parser('loto', help='Buy loto tickets. See information on drawing')
ploto_a = ploto.add_argument_group("action")
ploto_a.add_argument('--buy', action='store', dest='buy', default='', help='Buy a loto ticket.')
ploto_a.add_argument('--list', '-l', action='store_true', dest='list', default=False, help='List lottery history.')
ploto_a.add_argument('--info', '-i', action='store_true', dest='info', default=False, help='Display information on current drawing.')

pcatProg = subparsers.add_parser('catProg', help='Display category progression')

pflagProg = subparsers.add_parser('flagProg', help='Display flag progression')

pnews = subparsers.add_parser('news', help='Display News')

pinfo = subparsers.add_parser('info', help='Display team information and statistics')

psecrets = subparsers.add_parser('secrets', help='Display team secrets')
psecrets_a = psecrets.add_argument_group("action")
psecrets_a.add_argument('--list', '-l', action='store_true', dest='list', default=False, help='List settings.')

args = parser.parse_args()

if args.debug:
    print('[-] Arguments: ' + str(args))

# Step 1: Connect to API
try:
    c = PlayerController()
except Exception as e:
    print(e)
    exit(1)

# Step 2: Process user request
try:
    if args.action == 'submit':
        flag = args.flag
        assert type(flag) is str, "FLAG is not a string: %r" % flag
        print('[-] Submitting flag')
        print(c.submitFlag(flag))
    elif args.action == 'score':
        print('[-] Displaying score')
        print(c.getScore(config.DEFAULT_TOP_VALUE))
    elif args.action == 'bm':
        if args.buy != '':
            id = args.buy
            assert id.isdigit(), "ID is not an integer : %r" % id
            print("[+] Buying black market item")
            ret = c.buyBMItem(int(id))
            if ret != 0:
                print(ret)
        elif args.sell != '':
            try:
                name,desc,path,amount,qty = args.sell.split('|',4)
            except ValueError:
                try:
                    name,desc,path,amount = args.sell.split('|',3)
                    qty = None
                except ValueError:
                    print('Syntax error. RTFM')
                    exit(1)

            assert type(name) is str, "NAME is not a string: %r" % name
            assert type(desc) is str, "DESC is not a string: %r" % desc
            assert os.path.exists(path), "PATH is not a valid path: %r" % path
            assert os.path.getsize(path) < 1024*1024, "PATH is too big. File size must be smaller than 1mb."
            assert float(amount), "AMOUNT is not a float: %r" % amount
            assert qty == None or qty.isdigit()  , "QTY is not an integer: %r" % qty

            # Read file and create byte array
            data = b''
            with open(path, 'rb') as f:
                byte = f.read(1024)
                while byte != b'':
                    data += byte
                    byte = f.read(1024)
            f.close()
            
            if qty != None:
                qty = int(qty)
            rc = c.sellBMItem(name,amount,qty,desc,Binary(data))
            if rc == 0:
                print('The item was send successfully. An admin will review it shortly.')
            else:
                print('An error occured while sending the file: %s' % rc)
        elif args.info != '':
            id = args.info
            assert id.isdigit(), "ID is not an integer : %r" % id
            print("[+] Displaying black market item information")
            print(c.getBMItemInfo(int(id)))
        elif args.get != '':
            id = args.get
            assert id.isdigit(), "ID is not an integer : %r" % id
            print("[+] Downloading black market item")
            link = c.getBMItemLink(int(id))

            # Parse byte array and write file
            if link.startswith('http'):
                # Download item
                try:
                    f = urlopen(link,cafile=config.PLAYER_API_SSL_ROOT_CA)
                    data = f.read()
                except URLError as e:
                    print('Black market item download failed. %s' % e.reason)
                except Exception as e:
                    print(e)

                # Save item
                if data:
                    path = urlparse(link).path
                    filename = os.path.basename(path)
                    with open(filename, 'wb') as f:
                        f.write(bytes(x for x in data))
                    f.close()
                    print("[+] %s bytes were saved at %s" % (len(data),filename))
            else:
                print('Black market item download canceled: %s' % link)

        elif args.list:
            print("[+] Displaying black market items")
            print(c.getBMItemList(config.DEFAULT_TOP_VALUE))
        elif args.listCategories:
            print("[+] Displaying black market item categories")
            print(c.getBMItemCategoryList())
        elif args.listStatus:
            print("[+] Displaying black market item status")
            print(c.getBMItemStatusList())
        else: 
            parser.print_help()
            print('No subaction choosen')
    elif args.action == 'loto':
        if args.buy != '':
            id = args.buy
            assert id.isdigit(), "ID is not an integer : %r" % id
            print("[+] Buying tickets")
            print(c.buyLoto(int(id)))
        elif args.list:
            print("[+] Displaying lottery history")
            print(c.getLotoHistory(config.DEFAULT_TOP_VALUE))
        elif args.info:
            print("[+] Displaying information on the current drawing")
            print(c.getLotoInfo())
    elif args.action == 'catProg':
        print('[-] Displaying category progression')
        print(c.getCatProgress())
    elif args.action == 'flagProg':
        print('[-] Displaying flag progression')
        print(c.getFlagProgress())
    elif args.action == 'news':
        print('[-] Displaying news')
        print(c.getNews())
    elif args.action == 'info':
        print('[-] Displaying team informations')
        print(c.getTeamInfo())
    elif args.action == 'secrets':
        print('[-] Displaying team\'s secrets')
        print(c.getTeamSecrets())
    else:
        parser.print_help()
except socket.error as e:
    print('[-] %s' % e)
except Fault as e:
    print('[-] %s' % e.faultString)
except ProtocolError as e:
    print('[-] An xmlrpc error occured: %s %s' % (e.errcode,e.errmsg))
except Exception as e:
    print(e)
else:
    if args.debug:
        print('[+] Job completed')


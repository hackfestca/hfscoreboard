#!/usr/bin/env python3
# -*- coding: utf-8 -*-

'''
This script is the main interface for admins to manage CTF

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
from lib import AdminController
from lib import SecTestController

# System imports
import psycopg2
import argparse
import os.path
from urllib.request import Request, urlopen, HTTPSHandler, build_opener
from urllib.error import URLError, HTTPError
from urllib.parse import urlparse

# Get args
usage = 'usage: %prog action [options]'
description = 'HF Scoreboard admin client. Use this tool to manage the CTF'
parser = argparse.ArgumentParser(description=description)
parser.add_argument('-v','--version', action='version', version='%(prog)s 1.1 (2015-11-07)')
parser.add_argument('--debug', action='store_true', dest='debug', default=False, \
                    help='Run the tool in debug mode')
subparsers = parser.add_subparsers(dest='action')
pteamDesc = '''\
variables:
    ID          int - Id of the team. Use --list to find the correct id.
    NAME        str - Name of the team. 
    NET         str - Network of the team. Ex: 172.29.102.0/24
    DESC        str - Description of the reward. Just explain why the team was rewarded.
    PTS         int - Number of points to give as a reward.
    AMOUNT      float - Amount of money to give for money laundering.
'''
pteamEpi = '''\
example: 
    --add 'TeamName|172.29.23.0/24'

    --mod '12|NewTeamName|172.29.23.0/24'

    --reward '31|For having raised a sqli in the scoreboard|300'

    --launder '25|500'
'''
pteam = subparsers.add_parser('team', description=pteamDesc, epilog=pteamEpi, 
                              formatter_class=argparse.RawDescriptionHelpFormatter, help='Manage teams.')
pteam_a = pteam.add_argument_group("Action")
pteam_o = pteam.add_argument_group("Option")
pteam_a.add_argument('--add', action='store', dest='add', default='', type=str, metavar='\'NAME|NET\'', \
                     help='Add a team.')
pteam_a.add_argument('--mod', action='store', dest='mod', default='', type=str, metavar='\'ID|NAME|NET\'', \
                     help='Modify a team.')
pteam_a.add_argument('--reward', action='store', dest='reward', default='', type=str, metavar='\'ID|DESC|PTS\'', \
                     help='Reward a team. ')
pteam_a.add_argument('--launder', action='store', dest='launder', default=None, type=str, metavar='\'ID|AMOUNT\'', \
                     help='Launder money for a team. ')
pteam_a.add_argument('--list', '-l', action='store_true', dest='list', default=False, help='List teams.')
pteam_a.add_argument('--variables', action='store_true', dest='variables', default=False, help='List team variables.')
pteam_o.add_argument('--grep', action='store', dest='grep', default=None, type=str, metavar='STR', \
                     help='For --list only. Filter result by searching a specific string.')

pnewsDesc = '''\
variables:
    ID          int - Id of the team. Use --list to find the correct id.
    NEWS        str - News title.
    TS          timestamp - (optional) Timestamp at which the news will be displayed.
'''
pnewsEpi = '''\
example: 
    --add 'Team A is dominating!'
    --add 'Huge leak have appeared on the black market!|2015-11-07 23:00'

    --mod '6|Team B is dominating!'
'''
pnews = subparsers.add_parser('news', description=pnewsDesc, epilog=pnewsEpi,
                              formatter_class=argparse.RawDescriptionHelpFormatter, help='Manage news.')
pnews_a = pnews.add_argument_group("action")
pnews_o = pnews.add_argument_group("option")
pnews_a.add_argument('--add', action='store', dest='add', default='', type=str, metavar='\'NEWS|TS\'', \
                     help='Add a news.')
pnews_a.add_argument('--mod', action='store', dest='mod', default='', type=str, metavar='\'ID|NEWS|TS\'', \
                     help='Modify a news.')
pnews_a.add_argument('--list', '-l', action='store_true', dest='list', default=False, help='List news.')

pflagDesc = '''\
variables:
    FLAG        str - Some flag value. It should be 64 character long.
'''
pflagEpi = '''\
example: 
    --check 274e69de8ccaf3c13d36dc31b2d862996ba89a0e
'''
pflag = subparsers.add_parser('flag', description=pflagDesc, epilog=pflagEpi,
                              formatter_class=argparse.RawDescriptionHelpFormatter, help='Manage flags.')
pflag_a = pflag.add_argument_group("action")
pflag_o = pflag.add_argument_group("option")
pflag_a.add_argument('--check', action='store', dest='check', default='', type=str, metavar='\'FLAG\'', \
                     help='Check if this is a valid flag or not.')
pflag_a.add_argument('--list', '-l', action='store_true', dest='list', default=False, help='List flags.')

pbmDesc = '''\
variables:
    ID          int - Item id. 
    NAME        str - Name of the item. Make it short and sweet.
    DESC        str - Description of the item. Make it teasy!
    PATH        str - Path to the file to be uploaded. All format are supported.
    AMOUNT      float - Cost of the item. Cannot be < 0.
    QTY         int - (optional) Max number of time the item can get bought. Cannot be < 0. Default = 0 (no limit).
    DISP        interval - (optional) Display interval. Format: '2015-11-07 22:00'. Default = Null

    APPROVE     bool - Approve or not an item. 1 = approved, 0 = denied.
    STATUS      int - Item status code. Use --list-status to see full list.
    RATING      int - Rating from 0 to 5, 0 being shit and 5 being awesome.
    COMMENTS    str - Put comments to describe what you think of this item.
'''
pbmEpi = '''\
examples:
    --add 'Track 1 leak|Buying this item is like buying a glass of scotch, you will simply enjoy.|/home/martin/track1.zip|5000'
    --add 'Track 1 leak|Buying this item is like buying a glass of scotch, you will simply enjoy.|/home/martin/track1.zip|5000|2'
    --add 'Track 1 leak|Buying this item is like buying a glass of scotch, you will simply enjoy.|/home/martin/track1.zip|5000|2|5 hours'

    --mod 'Track 2 leak|Buying this item is like buying a glass of scotch, you will simply enjoy.|/home/martin/track1.zip|5000|2|5 hours'

    --allow '1|5|Good item. Seem legit and functional'
    --deny '2|1|This item looks like bullshit'
    --deny '3|0|You cannot hide flags in your items'

    --setStatus '3|1'   # Set item id 3 for sale
    --setStatus '3|5'   # Remove item id 3 from game
'''
pbm = subparsers.add_parser('bm', description=pbmDesc, epilog=pbmEpi,\
                            formatter_class=argparse.RawDescriptionHelpFormatter,\
                            help='Manage black market items.')
pbm_a = pbm.add_argument_group("action")
pbm_o = pbm.add_argument_group("option")
pbm_a.add_argument('--add', action='store', dest='add', default='', type=str, metavar='\'NAME|DESC|PATH|AMOUNT|QTY|DISP\'', \
                   help='Add an item on the black market.')
pbm_a.add_argument('--mod', action='store', dest='mod', default='', type=str, metavar='\'ID|NAME|DESC|AMOUNT|QTY|DISP\'', \
                   help='Modify an item on the black market.')
pbm_a.add_argument('--info', action='store', dest='info', default='', metavar='\'ID\'', \
                   help='Show an item information.')
pbm_a.add_argument('--get', action='store', dest='get', default='', metavar='\'ID\'', \
                   help='Download an item.')
pbm_a.add_argument('--allow', action='store', dest='allow', default='', type=str, metavar='\'ID|RATING|COMMENTS\'', \
                   help='Review an item (accept it to go on the black market).')
pbm_a.add_argument('--deny', action='store', dest='deny', default='', type=str, metavar='\'ID|RATING|COMMENTS\'', \
                   help='Review an item (deny it from going on the black market).')
pbm_a.add_argument('--setStatus', action='store', dest='setStatus', default='', type=str, metavar='\'ID|STATUS\'', \
                   help='Change status of an item.')
pbm_a.add_argument('--list', '-l', action='store_true', dest='list', default=False, help='List black market items.')
pbm_a.add_argument('--list-categories', action='store_true', dest='listCategories', default=False, help='List item categories.')
pbm_a.add_argument('--list-status', action='store_true', dest='listStatus', default=False, help='List item status.')

pwallet = subparsers.add_parser('cash', help='Manage cash (wallet and loto).')
pwallet_a = pwallet.add_argument_group("action")
pwallet_a.add_argument('--list-transactions', action='store_true', dest='listTransactions', default=False, help='List transaction history.')
pwallet_a.add_argument('--list-loto', action='store_true', dest='listLoto', default=False, help='List loto history.')

psettingsDesc = '''\
variables:
    TS      timestamp - Date format. Example: '2015-11-07 18:00'
'''
psettingsEpi = '''\
examples:
    --startNow
    --startAt '2015-11-07 16:00'
    --endNow
    --endAt '2015-11-08 02:30'
'''
psettings = subparsers.add_parser('settings', description=psettingsDesc, epilog=psettingsEpi,\
                            formatter_class=argparse.RawDescriptionHelpFormatter,\
                            help='Manage game settings.')
psettings_a = psettings.add_argument_group("action")
psettings_a.add_argument('--startAt', action='store', dest='gameStart', default='', type=str, \
                       metavar='TS', 
                       help='Set a game start date/time.')
psettings_a.add_argument('--startNow', action='store_true', dest='startNow', default=False, \
                       help='Start the game now!')
psettings_a.add_argument('--endAt', action='store', dest='gameEnd', default='', type=str, \
                       metavar='TS', 
                       help='Set a game end date/time.')
psettings_a.add_argument('--endNow', action='store_true', dest='endNow', default=False, \
                       help='End the game now!')
psettings_a.add_argument('--list', '-l', action='store_true', dest='list', default=False, help='List settings.')

pscoreDesc = '''\
variables:
    TS      timestamp - Date format. Example: '2015-11-07 18:00'
'''
pscore = subparsers.add_parser('score', description=psettingsDesc,
                               formatter_class=argparse.RawDescriptionHelpFormatter,
                               help='Print score table (table, matrix).')
pscore_a = pscore.add_argument_group("action")
pscore_o = pscore.add_argument_group("option")
pscore_a.add_argument('--table', action='store_true', dest='table', default=False, \
                      help='Print score table (classic).')
pscore_a.add_argument('--graph', action='store_true', dest='graph', default=False, \
                      help='Print score graph.')
pscore_a.add_argument('--matrix', action='store_true', dest='matrix', default=False, \
                      help='Print progression matrix.')
pscore_a.add_argument('--csv', action='store_true', dest='csv', default=False, \
                      help='Print progression in csv format.')
pscore_o.add_argument('--ts', action='store', dest='ts', default=None, \
                      type=str, metavar='TS', \
                      help='Use to get the score at a specific time. Default is now.')

pstatDesc = '''\
variables:
    FILTER  str - (optional) Filter which flag to print progression. Example: ssh%
    T_ID    int - Team id
    F_NAME  str - Flag name. Example: re01
'''
pstatEpi = '''\
examples:
    --list
    --flagsSubmitHistory
    --flagsSubmitCount 'ssh%'
    --teamProgress 12           # Print progression of team 12
    --flagProgress re03         # Print who successfully submitted flag re03
'''
pstats = subparsers.add_parser('stat', description=pstatDesc, epilog=pstatEpi,
                               formatter_class=argparse.RawDescriptionHelpFormatter,
                               help='Display game stats, progression, history')
pstats_a = pstats.add_argument_group("action")
pstats_o = pstats.add_argument_group("option")
pstats_a.add_argument('--flagsSubmitHistory', action='store_true', dest='flagsSubmitHistory', default=False,\
                      help='Print history of successfully submitted flags.')
pstats_a.add_argument('--flagsSubmitCount', action='store', dest='flagsSubmitCount',\
                      default='', type=str, metavar='FILTER', \
                      help='Print number of successful submit per challenge.')
pstats_a.add_argument('--teamProgress', action='store', dest='teamProgress',\
                      default='', type=str, metavar='T_ID',\
                      help='Print all submitted flags of a specific team.')
pstats_a.add_argument('--flagProgress', action='store', dest='flagProgress',\
                      default='', type=str, metavar='F_NAME',\
                      help='Print all teams who successfuly submitted a specific flag.')
pstats_a.add_argument('--list', '-l', action='store_true', dest='general', default=False, \
                      help='Print general stats about the game (flags qty, submit attempts, etc.)')

pevents = subparsers.add_parser('events', help='Display game events.')
pevents_a = pevents.add_argument_group("action")
pevents_o = pevents.add_argument_group("option")
pevents_a.add_argument('--list', '-l', action='store_true', dest='list', default=False, \
                       help='List events')
pevents_a.add_argument('--live', action='store_true', dest='live', default=False, \
                       help='List events as they appear in the database.')

pbench = subparsers.add_parser('bench', help='Benchmark some db stored procedure.')
pbench.add_argument('-n', action='store', dest='reqNum', default=100, \
                    type=int, metavar='NB_OF_REQ', \
                    help='Use to specify number of requests. Default is 100.')
pconbench = subparsers.add_parser('conbench', help='Benchmark some db stored procedure using multiple connections.')
pconbench.add_argument('-n', action='store', dest='reqNum', default=50, \
                       type=int, metavar='NB_OF_REQ', \
                       help='Use to specify number of requests. Default is 100.')
pconbench.add_argument('-c', action='store', dest='reqCon', default=30, \
                       type=int, metavar='CONCURRENCY', \
                       help='Use to specify number of multiple requests to make. Default is 30.')
psec = subparsers.add_parser('security', help='Test database security.')

args = parser.parse_args()

rc = 0

if args.debug:
    print('[-] Arguments: ' + str(args))

# Special case: No exceptions handling for database security tests
if args.action == 'security':
    print("Testing database security")
    c = SecTestController.SecTestController()
    c.testSecurity()
    c.close()
    print('[+] Database security was tested successfuly')
    exit(0)

# Step 1: Connect to database
try:
    c = AdminController.AdminController()
    c.setDebug(args.debug)
except psycopg2.Warning as e:
    print('[-] ' + str(e))
except psycopg2.Error as e:
    print('[-] ' + str(e))
    exit(1)
except Exception as e:
    print(e)
    exit(1)

# Step 2: Process user request
try:
    if args.action == 'team':
        if args.add:
            name,net = args.add.split('|',1)
            print('Adding team with name=%s, net=%s' % (name,net))
            rc = c.addTeam(name,net)
        elif args.mod:
            id,name,net = args.mod.split('|',2)
            assert id.isdigit(), "ID is not an integer: %r" % id
            assert type(name) is str, "NAME is not a string: %r" % name
            assert type(net) is str, "NET is not a string: %r" % net
            rc = c.modTeam(int(id),name,net)
        elif args.reward:
            id,desc,pts = args.reward.split('|',2)
            assert id.isdigit(), "ID is not an integer: %r" % id
            assert type(desc) is str, "DESC is not a string: %r" % desc
            assert pts.isdigit(), "PTS is not a integer: %r" % pts
            rc = c.rewardTeam(int(id),desc,int(pts))
        elif args.launder:
            id,cash = args.launder.split('|',1)
            assert id.isdigit(), "ID is not an integer: %r" % id
            assert float(cash), "CASH is not a float: %r" % cash
            rc = c.launderMoney(int(id),float(cash))
        elif args.list:
            print('[+] Displaying teams informations (grep "'+str(args.grep)+'",top '+str(config.DEFAULT_TOP_VALUE)+')')
            print(c.getFormatTeamList(args.grep,config.DEFAULT_TOP_VALUE))
        elif args.variables:
            print('[+] Displaying teams variables (grep "'+str(args.grep)+'",top '+str(config.DEFAULT_TOP_VALUE)+')')
            print(c.getFormatTeamsVariables(args.grep,config.DEFAULT_TOP_VALUE))
        else: 
            parser.print_help()
            print('No subaction choosen')
    elif args.action == 'news':
        if args.add != '':
            try:
                news,ts = args.add.split('|',1)
            except ValueError:
                news = args.add
                ts = None
            assert type(news) is str, "NEWS is not a string: %r" % news
            assert type(ts) is str or ts == None, "TS is not a string: %r" % ts
            rc = c.addNews(news,ts)
            print('Return Code: '+str(rc))
        elif args.mod:
            try:
                id,news,ts = args.mod.split('|',2)
            except ValueError:
                id,news = args.mod.split('|',1)
                ts = None
            assert id.isdigit(), "ID is not a integer: %r" % id
            assert type(news) is str, "NEWS is not a string: %r" % news
            assert type(ts) is str or ts == None, "TS is not a string: %r" % ts
            rc = c.modNews(int(id),news,ts)
            print('Return Code: '+str(rc))
        elif args.list:
            print("[+] Displaying news")
            print(c.getFormatNews())
        else: 
            parser.print_help()
            print('No subaction choosen')
    elif args.action == 'flag':
        if args.check != '':
            flag = args.check
            assert type(flag) is str, "FLAG is not a string: %r" % flag
            print("[+] Checking flag validity")
            print(c.checkFlag(flag))
        elif args.list:
            print("[+] Displaying flags")
            print(c.getFormatFlagList())
        else: 
            parser.print_help()
            print('No subaction choosen')
    elif args.action == 'bm':
        if args.add != '':
            try:
                name,desc,path,amount,qty,disp = args.add.split('|',5)
            except ValueError:
                try:
                    name,desc,path,amount,qty = args.add.split('|',4)
                    disp = None
                except ValueError:
                    name,desc,path,amount = args.add.split('|',3)
                    disp = None
                    qty = None
            assert type(name) is str, "NAME is not a string: %r" % name
            assert type(desc) is str, "DESC is not a string: %r" % desc
            assert os.path.exists(path), "PATH is not a valid path: %r" % path
            assert float(amount), "AMOUNT is not a float: %r" % amount
            assert qty == None or qty.isdigit()  , "QTY is not an integer: %r" % qty
            assert type(disp) is str or disp == None, "DISP is not a string: %r" % disp

            # Read file and create byte array
            data = b''
            with open(path, 'rb') as f:
                byte = f.read(1024)
                while byte != b'':
                    data += byte
                    byte = f.read(1024)
            f.close()

            rc = c.addBMItem(name,amount,int(qty),disp,desc,data)
            print('Return Code: '+str(rc))
        elif args.mod:
            try:
                id,name,desc,amount,qty,disp = args.mod.split('|',5)
            except ValueError:
                try:
                    id,name,desc,amount,qty = args.mod.split('|',4)
                    disp = None
                except ValueError:
                    id,name,desc,amount = args.mod.split('|',3)
                    disp = None
                    qty = None
            assert id.isdigit(), "ID is not an integer : %r" % id
            assert type(name) is str, "NAME is not a string: %r" % name
            assert type(desc) is str, "DESC is not a string: %r" % desc
            assert float(amount), "AMOUNT is not a float: %r" % amount
            assert qty == None or qty.isdigit()  , "QTY is not an integer: %r" % qty
            assert type(disp) is str or disp == None, "DISP is not a string: %r" % disp

            rc = c.modBMItem(int(id),name,amount,int(qty),disp,desc)
            print('Return Code: '+str(rc))
        elif args.info != '':
            id = args.info
            assert id.isdigit(), "ID is not an integer : %r" % id
            print("[+] Displaying black market item information")
            print(c.getFormatBMItemInfo(int(id)))
        elif args.get != '':
            id = args.get
            assert id.isdigit(), "ID is not an integer : %r" % id
            print("[+] Downloading black market item")
            link = c.getBMItemLink(int(id))

            # Parse byte array and write file
            if link.startswith('http'):
                # Download item
                data = b''
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
        elif args.allow != '':
            id,rating,comments = args.allow.split('|',3)
            assert id.isdigit(), "ID is not an integer : %r" % id
            assert rating.isdigit(), "RATING is not an integer : %r" % rating
            assert type(comments) is str, "COMMENTS is not a string: %r" % comments
            print("[+] Reviewing black market item")
            rc = c.reviewBMItem(int(id),True,int(rating),comments)
        elif args.deny != '':
            id,rating,comments = args.deny.split('|',3)
            assert id.isdigit(), "ID is not an integer : %r" % id
            assert rating.isdigit(), "RATING is not an integer : %r" % rating
            assert type(comments) is str, "COMMENTS is not a string: %r" % comments
            print("[+] Reviewing black market item")
            rc = c.reviewBMItem(int(id),False,int(rating),comments)
        elif args.setStatus != '':
            id,status = args.setStatus.split('|',1)
            assert id.isdigit(), "ID is not an integer : %r" % id
            assert status.isdigit(), "STATUS is not an integer : %r" % status
            print("[+] Changing status of a black market item")
            rc = c.setBMItemStatus(int(id),int(status))
        elif args.list:
            print("[+] Displaying black market items")
            print(c.getFormatBMItemList(config.DEFAULT_TOP_VALUE))
        elif args.listCategories:
            print("[+] Displaying black market item categories")
            print(c.getFormatBMItemCategoryList())
        elif args.listStatus:
            print("[+] Displaying black market item status")
            print(c.getFormatBMItemStatusList())
        else: 
            parser.print_help()
            print('No subaction choosen')
    elif args.action == 'cash':
        if args.listTransactions:
            print("[+] Displaying transactions history")
            print(c.getFormatTransactionHistory(config.DEFAULT_TOP_VALUE))
        elif args.listLoto:
            print("[+] Displaying loto history")
            print(c.getFormatLotoHistory(config.DEFAULT_TOP_VALUE))
        else: 
            parser.print_help()
            print('No subaction choosen')
    elif args.action == 'settings':
        if args.startNow:
            c.startGame()
        elif args.gameStart:
            c.setSetting('gameStartTs',args.gameStart,'timestamp')
        elif args.endNow:
            c.endGame()
        elif args.gameEnd:
            c.setSetting('gameEndTs',args.gameEnd,'timestamp')
        elif args.list:
            print("[+] Displaying settings")
            print(c.getFormatSettings())
        else: 
            parser.print_help()
            print('No subaction choosen')
    elif args.action == 'score':
        if args.table:
            print('[+] Displaying score (top '+str(config.DEFAULT_TOP_VALUE)+')')
            print(c.getFormatScore(config.DEFAULT_TOP_VALUE,args.ts))
        elif args.graph:
            print('[+] Displaying graph (top '+str(config.DEFAULT_TOP_VALUE)+')')
            print(c.getGraphScore(config.DEFAULT_TOP_VALUE))
        elif args.matrix:
            print("[+] Displaying progression matrix")
            print(c.getFormatScoreProgress())
        elif args.csv:
            print("[+] Displaying progression in csv format")
            print(c.getCsvScoreProgress())
        else:
            print('[+] Displaying score (top '+str(config.DEFAULT_TOP_VALUE)+')')
            print(c.getFormatScore(config.DEFAULT_TOP_VALUE,args.ts))
    elif args.action == 'history':
        print('[+] Displaying submit history(top '+str(config.DEFAULT_TOP_VALUE)+', type '+str(args.type)+')')
        print(c.getFormatSubmitHistory(config.DEFAULT_TOP_VALUE,args.type))
    elif args.action == 'stat':
        if args.general:
            print("[+] Displaying games stats")
            print(c.getFormatGameStats())
        elif args.flagsSubmitCount != '':
            print("[+] Displaying flags submit count")
            print(c.getFormatFlagsSubmitCount(args.flagsSubmitCount))
        elif args.teamProgress:
            if args.id:
                print("[+] Displaying team progression")
                print(c.getFormatTeamProgress(args.id))
            else:
                print('You must specify a team id with --id')
        elif args.flagProgress != '':
            print("[+] Displaying flag progression")
            print(c.getFormatFlagProgress(args.flagProgress))
        else:
            print("[+] Displaying stats")
            print(c.getFormatGameStats())
    elif args.action == 'events':
        if args.list:
            print("[+] Displaying events")
            print(c.getFormatEvents())
        elif args.live:
            print("[+] Displaying events IRL")
            c.printLiveFormatEvents()
        else:
            print("[+] Displaying events")
            print(c.getFormatEvents())
    elif args.action == 'bench':
        print("Benchmarking database")
        c.benchmarkDB(args.reqNum)
    elif args.action == 'conbench':
        print("Benchmarking database connections")
        c.benchmarkDBCon(args.reqNum,args.reqCon)
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
        if rc == 0:
            print('[+] Job completed')
        else:
            print('An error occured. Return Code: '+str(rc))

c.close()


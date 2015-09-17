#!/usr/bin/python3
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
import postgresql.exceptions
import argparse

# Get args
usage = 'usage: %prog action [options]'
description = 'HF Scoreboard admin client. Use this tool to manage the CTF'
parser = argparse.ArgumentParser(description=description)
parser.add_argument('-v','--version', action='version', version='%(prog)s 1.1 (2015-11-07)')
parser.add_argument('--debug', action='store_true', dest='debug', default=False, \
                    help='Run the tool in debug mode')

subparsers = parser.add_subparsers(dest='action')
pteam = subparsers.add_parser('team', help='Manage teams.')
pteam_a = pteam.add_argument_group("Action")
pteam_o = pteam.add_argument_group("Option")
pteam_a.add_argument('--add', action='store', dest='add', default='', type=str, metavar='\'NAME|SUBNET\'', \
                     help='Add a team. Example: --add \'TeamName|172.29.23.0/24\'.')
pteam_a.add_argument('--mod', action='store', dest='mod', default='', type=str, metavar='\'ID|NAME|SUBNET\'', \
                     help='Modify a team. Example: --mod \'12|NewTeamName|172.29.23.0/24\'')
pteam_a.add_argument('--reward', action='store', dest='reward', default='', type=str, metavar='\'ID|DESC|PTS\'', \
                     help='Reward a team. Example: --reward \'31|For having raised a sqli in the scoreboard|300\'')
pteam_a.add_argument('--launder', action='store', dest='launder', default=None, type=str, metavar='\'ID|AMOUNT\'', \
                     help='Launder money for a team. Example: --launder \'4|500\'')
pteam_a.add_argument('--list', '-l', action='store_true', dest='list', default=False, help='List teams.')
pteam_a.add_argument('--variables', action='store_true', dest='variables', default=False, help='List team variables.')
pteam_o.add_argument('--grep', action='store', dest='grep', default=None, type=str, metavar='STR', \
                     help='For --list only. Filter result by searching a specific string.')
pteam_o.add_argument('--top', '-t', action='store', dest='top', default=config.DEFAULT_TOP_VALUE, \
                     type=int, metavar='NUM', \
                     help='For --list only. Use to specify number of rows to display. Default is 30.')

pnews = subparsers.add_parser('news', help='Manage news.')
pnews_a = pnews.add_argument_group("action")
pnews_o = pnews.add_argument_group("option")
pnews_a.add_argument('--add', action='store', dest='add', default='', type=str, metavar='\'NEWS\'', \
                     help='Add a news. Example: --add \'Team A is dominating!\'.')
pnews_a.add_argument('--mod', action='store', dest='mod', default='', type=str, metavar='\'NEWS\'', \
                     help='Modify a news. Use with --id to identify which news to update. \
                           Example: --mod \'This is another news\' --id 2.')
pnews_a.add_argument('--list', '-l', action='store_true', dest='list', default=False, help='List news.')
pnews_o.add_argument('-t', '--ts', action='store', dest='timestamp', metavar='\'TS\'', default='', type=str, \
                     help='For --add only. Use to specify when to display the news. \
                           Date and time must be specified. \
                           Example: --add \'Challenge D is unlocked!\' --ts \'2014-11-08 23:00\'.')
pnews_o.add_argument('--id', '-i', action='store', dest='id', default=0, type=int, 
                     help='For --mod only. Use to identify which news to update.')

pflag = subparsers.add_parser('flag', help='Manage flags.')
pflag_a = pflag.add_argument_group("action")
pflag_o = pflag.add_argument_group("option")
pflag_a.add_argument('--check', action='store', dest='check', default='', type=str, metavar='\'FLAG\'', \
                     help='Check if this is a valid flag or not.')
pflag_a.add_argument('--list', '-l', action='store_true', dest='list', default=False, help='List flags.')
pflag_o.add_argument('--top', '-t', action='store', dest='top', default=config.DEFAULT_TOP_VALUE, \
                     type=int, metavar='NUM', \
                     help='For --list only. Use to specify number of rows to display. Default is 30.')

pbmDesc = '''\
variables:
    NAME        str - Name of the item. Make it short and sweet.
    DESCRIPTION str - Description of the item. Make it teasy!
    PATH        str - Path to the file to be uploaded. All format are supported.
    AMOUNT      float - Cost of the item. Cannot be < 0.
    QTY         int - Max number of time the item can get bought. Cannot be < 0. Default = 0 (no limit).
    DISP        interval - Display interval. Format: '2015-11-07 22:00'. Default = Null

    STATUS      str - Item status. Use --list-status to see full list.
    RATING      int - Rating from 0 to 5, 0 being shit and 5 being awesome.
    COMMENTS    str - Put comments to describe what you think of this item.

'''
pbmEpi = '''\
examples:
    --add 'Track 1 leak|Buying this item is like buying a glass of scotch, you will simply enjoy.|/home/martin/track1.zip|5000'

    --review '1|For Sale|4|Good item. Seem legit and functional'
    --review '2|For Sale|1|This item looks like bullshit'
    --review '3|Refused by admin|0|You cannot hide flags in your items'
'''
pbm = subparsers.add_parser('bm', description=pbmDesc, epilog=pbmEpi,\
                            formatter_class=argparse.RawDescriptionHelpFormatter,\
                            help='Manage black market items.')
pbm_a = pbm.add_argument_group("action")
pbm_o = pbm.add_argument_group("option")
pbm_a.add_argument('--add', action='store', dest='add', default='', type=str, metavar='\'NAME|DESCRIPTION|PATH|AMOUNT|QTY|DISP\'', \
                   help='Add an item on the black market.')
pbm_a.add_argument('--mod', action='store', dest='mod', default='', type=str, metavar='\'ID|NAME|DESCRIPTION|PATH|AMOUNT|QTY|DISP\'', \
                   help='Modify an item on the black market.')
pbm_a.add_argument('--show', action='store', dest='show', default='', metavar='\'ID\'', \
                   help='Show an item information.')
pbm_a.add_argument('--get', action='store', dest='get', default='', metavar='\'ID\'', \
                   help='Download an item.')
pbm_a.add_argument('--review', action='store', dest='review', default='', type=str, metavar='\'ID|STATUS|RATING|COMMENTS\'', \
                   help='Review an item.')
pbm_a.add_argument('--setStatus', action='store', dest='setStatus', default='', type=str, metavar='\'ID|STATUS\'', \
                   help='Change status of an item.')
pbm_a.add_argument('--list', '-l', action='store_true', dest='list', default=False, help='List flags.')
pbm_a.add_argument('--list-transactions', action='store_true', dest='listTransactions', default=False, help='List black market transactions.')
pbm_a.add_argument('--list-categories', action='store_true', dest='listCategories', default=False, help='List item categories.')
pbm_a.add_argument('--list-status', action='store_true', dest='listStatus', default=False, help='List item status.')
pbm_o.add_argument('--top', '-t', action='store', dest='top', default=config.DEFAULT_TOP_VALUE, \
                   type=int, metavar='NUM', \
                   help='For --list only. Use to specify number of rows to display. Default is 30.')

pwallet = subparsers.add_parser('wallet', help='Manage wallets (cash).')
pwallet_a = pwallet.add_argument_group("action")
pwallet_a.add_argument('--list', '-l', action='store_true', dest='list', default=False, help='List transaction history.')

ploto = subparsers.add_parser('loto', help='Manage lotos.')
ploto_a = ploto.add_argument_group("action")
ploto_a.add_argument('--randomWinner', action='store_true', dest='randomWinner', default=False, help='Set a random winner.')
ploto_a.add_argument('--winner', action='store_true', dest='winner', default=False, help='Set a specific winner.')
ploto_a.add_argument('--list', '-l', action='store_true', dest='list', default=False, help='List transaction history.')

psettings = subparsers.add_parser('settings', help='Manage game settings.')
psettings.add_argument('--startAt', action='store', dest='gameStart', default='', type=str, \
                       metavar='TIMESTAMP', 
                       help='Set a game start date/time. Example: --startAt \'2014-11-08 10:00\'')
psettings.add_argument('--startNow', action='store_true', dest='startNow', default=False, \
                       help='Start the game now!')
psettings.add_argument('--endAt', action='store', dest='gameEnd', default='', type=str, \
                       metavar='TIMESTAMP', 
                       help='Set a game end date/time. Example: --endAt \'2014-11-08 10:00\'')
psettings.add_argument('--endNow', action='store_true', dest='endNow', default=False, \
                       help='End the game now!')
psettings.add_argument('--list', '-l', action='store_true', dest='list', default=False, help='List settings.')

pscore = subparsers.add_parser('score', help='Print score table (table, matrix).')
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
pscore_o.add_argument('--top', '-t', action='store', dest='top', default=config.DEFAULT_TOP_VALUE, \
                      type=int, metavar='NUM', \
                      help='Use to specify number of rows to display. Default is 30.')
pscore_o.add_argument('--ts', '-s', action='store', dest='ts', default=None, \
                      type=str, metavar='TIMESTAMP', \
                      help='Use to get the score at a specific time. Default is now.')
phistory = subparsers.add_parser('history', help='Print Submit History.')
phistory.add_argument('--top', '-t', action='store', dest='top', default=config.DEFAULT_TOP_VALUE, \
                      type=int, metavar='NUM', \
                      help='Use to specify number of rows to display. Default is 30.')
phistory.add_argument('--type', action='store', dest='type', default=None, \
                      type=int, metavar='NUM', \
                      help='Specify flag type to display (None=all, 1=Flag, 2=KingFlag).')
pstats = subparsers.add_parser('stat', help='Display game stats.')
pstats_a = pstats.add_argument_group("action")
pstats_o = pstats.add_argument_group("option")
pstats_a.add_argument('--general', action='store_true', dest='general', default=False, \
                      help='Print general stats about the game (flags qty, submit attempts, etc.)')
pstats_a.add_argument('--flagsSubmitCount', action='store_true', dest='flagsSubmitCount', default=False, \
                      help='Print number of successful submit per challenge.')
pstats_a.add_argument('--teamProgress', action='store_true', dest='teamProgress', default=False, \
                      help='Print all submitted flags of a specific team.')
pstats_a.add_argument('--flagProgress', action='store_true', dest='flagProgress', default=False, \
                      help='Print all teams who successfuly submitted a specific flag.')
pstats_o.add_argument('--flagFilter', action='store', dest='flagFilter', default='%', type=str, metavar='SQL_FILTER', \
                      help='For --flagsSubmitCount only. Use to specify which flag to print progression. Example: --flagFilter \'ssh%%\'')
pstats_o.add_argument('--id', action='store', dest='id', default=0, type=int, metavar='TEAM_ID', \
                      help='For --teamProgress only. Use to specify which team to print progression for. Example: --id 14')
pstats_o.add_argument('--flagName', action='store', dest='flagName', default='', type=str, metavar='FLAG_NAME', \
                      help='For --flagProgress only. Use to specify which flags to search for. Example: --flagName \'ssh01\'')
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
    exit(1)

# Step 2: Process user request
try:
    if args.action == 'team':
        if args.add:
            name,net = args.add.split('|',2)
            print('Adding team with name=%s, net=%s' % (name,net))
            rc = c.addTeam(name,net)
        elif args.mod:
            id,name,net = args.mod.split('|',3)
            assert id.isdigit(), "id is not an integer: %r" % id
            assert type(name) is str, "name is not a string: %r" % name
            assert type(net) is str, "net is not a string: %r" % net
            print('Modifying team with name=%s, net=%s where id=%s' % (name,net,id))
            rc = c.modTeam(int(id),name,net)
        elif args.reward:
            id,desc,pts = args.reward.split('|',3)
            assert id.isdigit(), "id is not an integer: %r" % id
            assert type(desc) is str, "description is not a string: %r" % desc
            assert pts.isdigit(), "pts is not a integer: %r" % pts
            print('Rewarding team with desc=%s, pts=%s where id=%s' % (id,desc,pts))
            rc = c.rewardTeam(int(id),desc,int(pts))
        elif args.launder:
            id,cash = args.launder.split('|',2)
            assert id.isdigit(), "id is not an integer: %r" % id
            assert float(cash), "cash is not a float: %r" % cash
            print('Rewarding team for %s$ where id=%s' % (id,cash))
            rc = c.launderMoney(int(id),float(cash))
        elif args.list:
            print('Displaying teams informations (grep "'+str(args.grep)+'",top '+str(args.top)+')')
            print(c.getFormatTeamList(args.grep,args.top))
        elif args.variables:
            print('Displaying teams variables (grep "'+str(args.grep)+'",top '+str(args.top)+')')
            print(c.getFormatTeamsVariables(args.grep,args.top))
        else: 
            parser.print_help()
            print('No subaction choosen')
    elif args.action == 'news':
        if args.add != '':
            if args.timestamp != '':
                rc = c.addNews(args.add,args.timestamp)
            else:
                rc = c.addNews(args.add,None)
                print('Return Code: '+str(rc))
        elif args.mod:
            try:
                title = args.mod
                print('Modifying news with title='+title+' where id='+str(args.id))
                rc = c.modNews(args.id,title,args.timestamp)
                print('Return Code: '+str(rc))
            except ValueError:
                print('[-] Invalid input. Please RTFM')
        elif args.list:
            print("Displaying news")
            print(c.getFormatNews())
        else: 
            parser.print_help()
            print('No subaction choosen')
    elif args.action == 'flag':
        if args.check != '':
            flag = args.check
            print("Checking flag validity")
            print(c.checkFlag(flag))
        elif args.list:
            print("Displaying flags")
            print(c.getFormatFlagList())
        else: 
            parser.print_help()
            print('No subaction choosen')
    elif args.action == 'settings':
        if args.startNow:
            c.startGame()
        elif args.gameStart:
            c.setSetting('gameStartTs',args.gameStart,'timestamp')
        if args.endNow:
            c.endGame()
        elif args.gameEnd:
            c.setSetting('gameEndTs',args.gameEnd,'timestamp')
        elif args.list:
            print("Displaying settings")
            print(c.getFormatSettings())
        else: 
            parser.print_help()
            print('No subaction choosen')
    elif args.action == 'score':
        if args.table:
            print('Displaying score (top '+str(args.top)+')')
            print(c.getFormatScore(args.top,args.ts))
        elif args.graph:
            print('Displaying graph (top '+str(args.top)+')')
            print(c.getGraphScore(args.top))
        elif args.matrix:
            print("Displaying progression matrix")
            print(c.getFormatScoreProgress())
        elif args.csv:
            print("Displaying progression in csv format")
            print(c.getCsvScoreProgress())
        else:
            print('Displaying score (top '+str(args.top)+')')
            print(c.getFormatScore(args.top,args.ts))
    elif args.action == 'history':
        print('Displaying submit history(top '+str(args.top)+', type '+str(args.type)+')')
        print(c.getFormatSubmitHistory(args.top,args.type))
    elif args.action == 'stat':
        if args.general:
            print("Displaying games stats")
            print(c.getFormatGameStats())
        elif args.flagsSubmitCount:
            print("Displaying flags submit count")
            print(c.getFormatFlagsSubmitCount(args.flagFilter))
        elif args.teamProgress:
            if args.id:
                print("Displaying team progression")
                print(c.getFormatTeamProgress(args.id))
            else:
                print('You must specify a team id with --id')
        elif args.flagProgress:
            if args.flagName:
                print("Displaying flag progression")
                print(c.getFormatFlagProgress(args.flagName))
            else:
                print('You must specify a flag name with --flagName')
        else:
            print("Displaying stats")
            print(c.getFormatGameStats())
    elif args.action == 'events':
        if args.list:
            print("Displaying events")
            print(c.getFormatEvents())
        elif args.live:
            print("Displaying events IRL")
            c.printLiveFormatEvents()
        else:
            print("Displaying events")
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
except postgresql.exceptions.PLPGSQLRaiseError as e:
    print('[-] ('+str(e.code)+') '+e.message)
except postgresql.exceptions.InsufficientPrivilegeError:
    print('[-] Insufficient privileges')
except postgresql.exceptions.UniqueError as e:
    print('[-] Unique constraint violation ('+e.message+')')
except postgresql.exceptions.CheckError as e:
    print('[-] Check constraint violation ('+e.message+')')
except postgresql.exceptions.TextRepresentationError as e:
    print('[-] '+e.message)
except postgresql.exceptions.UndefinedFunctionError:
    print('[-] The specified function does not exist. Please contact an admin')
except postgresql.exceptions.DateTimeFormatError:
    print('[-] Date&Time format error')
except postgresql.exceptions.ClientCannotConnectError:
    print('[-] Could not connect to server')
except postgresql.message.Message as e:
    print(e)
except Exception as e:
    print(e)
else:
    if args.debug:
        print('[+] Job completed')
        print('Return Code: '+str(rc))

c.close()


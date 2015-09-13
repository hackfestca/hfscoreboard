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
parser_team = subparsers.add_parser('team', help='Manage teams.')
parser_team_action = parser_team.add_argument_group("Action")
parser_team_option = parser_team.add_argument_group("Option")
parser_team_action.add_argument('--add', action='store', dest='add', default='', type=str, metavar='\'NAME|SUBNET\'', \
                                help='Add a team. Example: --add \'TeamName|172.29.23.0/24\'.')
parser_team_action.add_argument('--mod', action='store', dest='mod', default='', type=str, metavar='\'NAME|SUBNET\'', \
                                 help='Modify a team. Use with --id to identity which team to update. \
                                       Example: --mod \'TeamName|172.29.24.0/24\' --id 4')
parser_team_action.add_argument('--reward', action='store', dest='reward', default='', type=str, metavar='\'DESC|PTS\'', \
                                 help='Reward a team. Use with --id to identity which team to reward. \
                                       Example: --reward \'For having raised a sqli in the scoreboard|300\' --id 4')
parser_team_action.add_argument('--launder', action='store', dest='launder', default=None, type=float, metavar='\'AMOUNT\'', \
                                 help='Launder money for a team. Use with --id to identity which team to give money. \
                                       Example: --launder 500 --id 4')
parser_team_action.add_argument('-l', '--list', action='store_true', dest='list', default=False, help='List teams.')
parser_team_action.add_argument('--variables', action='store_true', dest='variables', default=False, help='List team variables.')
parser_team_option.add_argument('--grep', action='store', dest='grep', default=None, type=str, metavar='STR', \
                                help='For --list only. Filter result by searching a specific string.')
parser_team_option.add_argument('-t', '--top', action='store', dest='top', default=config.DEFAULT_TOP_VALUE, \
                                type=int, metavar='NUM', \
                                help='For --list only. Use to specify number of rows to display. Default is 30.')
parser_team_option.add_argument('-i', '--id', action='store', dest='id', default=0, type=int, \
                                help='For --mod,--reward,--launder. Use to identify which team to update. \
                                      Example: --mod \'NewTeamName!\' --id 1.')

parser_news = subparsers.add_parser('news', help='Manage news.')
parser_news_action = parser_news.add_argument_group("action")
parser_news_option = parser_news.add_argument_group("option")
parser_news_action.add_argument('--add', action='store', dest='add', default='', type=str, metavar='\'NEWS\'', \
                                help='Add a news. Example: --add \'Team A is dominating!\'.')
parser_news_action.add_argument('--mod', action='store', dest='mod', default='', type=str, metavar='\'NEWS\'', \
                                help='Modify a news. Use with --id to identify which news to update. \
                                      Example: --mod \'This is another news\' --id 2.')
parser_news_action.add_argument('-l', '--list', action='store_true', dest='list', default=False, help='List news.')
parser_news_option.add_argument('-t', '--ts', action='store', dest='timestamp', metavar='\'TS\'', default='', type=str, \
                                help='For --add only. Use to specify when to display the news. \
                                      Date and time must be specified. \
                                      Example: --add \'Challenge D is unlocked!\' --ts \'2014-11-08 23:00\'.')
parser_news_option.add_argument('-i', '--id', action='store', dest='id', default=0, type=int, 
                                help='For --mod only. Use to identify which news to update.')

parser_flag = subparsers.add_parser('flag', help='Manage flags.')
parser_flag_action = parser_flag.add_argument_group("action")
parser_flag_option = parser_flag.add_argument_group("option")
parser_flag_action.add_argument('-l', '--list', action='store_true', dest='list', default=False, help='List flags.')
parser_flag_option.add_argument('-t', '--top', action='store', dest='top', default=config.DEFAULT_TOP_VALUE, \
                                type=int, metavar='NUM', \
                                help='For --list only. Use to specify number of rows to display. Default is 30.')

parser_settings = subparsers.add_parser('settings', help='Manage game settings.')
parser_settings.add_argument('--startAt', action='store', dest='gameStart', default='', type=str, \
                                 metavar='TIMESTAMP', 
                                help='Set a game start date/time. Example: --startAt \'2014-11-08 10:00\'')
parser_settings.add_argument('--startNow', action='store_true', dest='startNow', default=False, \
                                help='Start the game now!')
parser_settings.add_argument('--endAt', action='store', dest='gameEnd', default='', type=str, \
                                 metavar='TIMESTAMP', 
                                help='Set a game end date/time. Example: --endAt \'2014-11-08 10:00\'')
parser_settings.add_argument('--endNow', action='store_true', dest='endNow', default=False, \
                                help='End the game now!')
parser_settings.add_argument('-l', '--list', action='store_true', dest='list', default=False, help='List settings.')

parser_score = subparsers.add_parser('score', help='Print score table (table, matrix).')
parser_score_action = parser_score.add_argument_group("action")
parser_score_option = parser_score.add_argument_group("option")
parser_score_action.add_argument('--table', action='store_true', dest='table', default=False, \
                                help='Print score table (classic).')
parser_score_action.add_argument('--graph', action='store_true', dest='graph', default=False, \
                                help='Print score graph.')
parser_score_action.add_argument('--matrix', action='store_true', dest='matrix', default=False, \
                                help='Print progression matrix.')
parser_score_action.add_argument('--csv', action='store_true', dest='csv', default=False, \
                                help='Print progression in csv format.')
parser_score_option.add_argument('-t', '--top', action='store', dest='top', default=config.DEFAULT_TOP_VALUE, \
                                type=int, metavar='NUM', \
                                help='Use to specify number of rows to display. Default is 30.')
parser_score_option.add_argument('-s', '--ts', action='store', dest='ts', default=None, \
                                type=str, metavar='TIMESTAMP', \
                                help='Use to get the score at a specific time. Default is now.')
parser_history = subparsers.add_parser('history', help='Print Submit History.')
parser_history.add_argument('-t', '--top', action='store', dest='top', default=config.DEFAULT_TOP_VALUE, \
                                type=int, metavar='NUM', \
                                help='Use to specify number of rows to display. Default is 30.')
parser_history.add_argument('--type', action='store', dest='type', default=None, \
                                type=int, metavar='NUM', \
                                help='Specify flag type to display (None=all, 1=Flag, 2=KingFlag).')
parser_stats = subparsers.add_parser('stat', help='Display game stats.')
parser_stats_action = parser_stats.add_argument_group("action")
parser_stats_option = parser_stats.add_argument_group("option")
parser_stats_action.add_argument('--general', action='store_true', dest='general', default=False, \
                                help='Print general stats about the game (flags qty, submit attempts, etc.)')
parser_stats_action.add_argument('--flagsSubmitCount', action='store_true', dest='flagsSubmitCount', default=False, \
                                help='Print number of successful submit per challenge.')
parser_stats_action.add_argument('--teamProgress', action='store_true', dest='teamProgress', default=False, \
                                help='Print all submitted flags of a specific team.')
parser_stats_action.add_argument('--flagProgress', action='store_true', dest='flagProgress', default=False, \
                                help='Print all teams who successfuly submitted a specific flag.')
parser_stats_option.add_argument('--flagFilter', action='store', dest='flagFilter', default='%', type=str, metavar='SQL_FILTER', \
                                help='For --flagsSubmitCount only. Use to specify which flag to print progression. Example: --flagFilter \'ssh%%\'')
parser_stats_option.add_argument('--id', action='store', dest='id', default=0, type=int, metavar='TEAM_ID', \
                                help='For --teamProgress only. Use to specify which team to print progression for. Example: --id 14')
parser_stats_option.add_argument('--flagName', action='store', dest='flagName', default='', type=str, metavar='FLAG_NAME', \
                                help='For --flagProgress only. Use to specify which flags to search for. Example: --flagName \'ssh01\'')
parser_events = subparsers.add_parser('events', help='Display game events.')
parser_events_action = parser_events.add_argument_group("action")
parser_events_option = parser_events.add_argument_group("option")
parser_events_action.add_argument('-l', '--list', action='store_true', dest='list', default=False, \
                                help='List events')
parser_events_action.add_argument('--live', action='store_true', dest='live', default=False, \
                                help='List events as they appear in the database.')
parser_bench = subparsers.add_parser('bench', help='Benchmark some db stored procedure.')
parser_bench.add_argument('-n', action='store', dest='reqNum', default=100, \
                                type=int, metavar='NB_OF_REQ', \
                                help='Use to specify number of requests. Default is 100.')
parser_conbench = subparsers.add_parser('conbench', help='Benchmark some db stored procedure using multiple connections.')
parser_conbench.add_argument('-n', action='store', dest='reqNum', default=50, \
                                type=int, metavar='NB_OF_REQ', \
                                help='Use to specify number of requests. Default is 100.')
parser_conbench.add_argument('-c', action='store', dest='reqCon', default=30, \
                                type=int, metavar='CONCURRENCY', \
                                help='Use to specify number of multiple requests to make. Default is 30.')
parser_sec = subparsers.add_parser('security', help='Test database security.')

args = parser.parse_args()

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
            try:
                name,net = args.add.split('|',2)
                print('Adding team with name='+name+', net='+net)
                rc = c.addTeam(name,net)
                print('Return Code: '+str(rc))
            except ValueError:
                print('[-] Invalid input. Please RTFM')
        elif args.mod:
            try:
                name,net = args.mod.split('|',2)
                print('Modifying team with name='+name+', net='+net+' where id='+str(args.id))
                rc = c.modTeam(args.id,name,net)
                print('Return Code: '+str(rc))
            except ValueError:
                print('[-] Invalid input. Please RTFM')
        elif args.reward:
            try:
                desc,pts = args.reward.split('|',2)
                print('Rewarding team with desc='+desc+', pts='+pts+' where id='+str(args.id))
                rc = c.rewardTeam(args.id,desc,int(pts))
                print('Return Code: '+str(rc))
            except ValueError:
                print('[-] Invalid input. Please RTFM')
        elif args.launder:
            try:
                cash = args.launder
                print('Rewarding team for '+str(cash)+'$ where id='+str(args.id))
                rc = c.launderMoney(args.id,cash)
                print('Return Code: '+str(rc))
            except ValueError:
                print('[-] Invalid input. Please RTFM')
        elif args.list:
            print('Displaying teams informations (grep "'+str(args.grep)+'",top '+str(args.top)+')')
            print(c.getFormatTeamList(args.grep,args.top))
        elif args.variables:
            print('Displaying team variables (id '+str(args.id)+')')
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
        if args.list:
            print("Displaying flags")
            print(c.getFlagList())
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

c.close()


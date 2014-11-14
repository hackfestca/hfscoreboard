#!/usr/bin/python3
# -*- coding: utf-8 -*-

'''
This script is the main interface for admins to manage CTF

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
from lib import kothAdmin
from lib import kothSecTest

# System imports
import logging
import postgresql.exceptions
import argparse

# Some vars and constants
VERSION = '0.01'
DEBUG = True

# Some functions
def dump(obj):
    for attr in dir(obj):
        print("obj.%s = %s" % (attr, getattr(obj, attr)))

# Get args
usage = 'usage: %prog action [options]'
description = 'King of the Hill admin client. Use this tool to manage the King of the Hill game'
parser = argparse.ArgumentParser(description=description)
parser.add_argument('-v','--version', action='version', version='%(prog)s 2.0')
subparsers = parser.add_subparsers(dest='action')

#actGrp = parser.add_argument_group("Action", "Select one of these action")
#optGrp = parser.add_argument_group("Option", "Use any depending on choosen action")

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
parser_team_action.add_argument('-l', '--list', action='store_true', dest='list', default=False, help='List teams.')
parser_team_option.add_argument('-t', '--top', action='store', dest='top', default=config.KOTH_DEFAULT_TOP_VALUE, \
                                type=int, metavar='NUM', \
                                help='For --list only. Use to specify number of rows to display. Default is 30.')
parser_team_option.add_argument('-i', '--id', action='store', dest='id', default=0, type=int, \
                                help='For --mod only. Used to identify which team to update. \
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
                                help='For --add only. Used to specify when to display the news. \
                                      Date and time must be specified. \
                                      Example: --add \'Challenge D is unlocked!\' --ts \'2014-11-08 23:00\'.')
parser_news_option.add_argument('-i', '--id', action='store', dest='id', default=0, type=int, 
                                help='For --mod only. Used to identify which news to update.')

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
parser_score_option.add_argument('-t', '--top', action='store', dest='top', default=config.KOTH_DEFAULT_TOP_VALUE, \
                                type=int, metavar='NUM', \
                                help='Use to specify number of rows to display. Default is 30.')
parser_score_option.add_argument('-s', '--ts', action='store', dest='ts', default=None, \
                                type=str, metavar='TIMESTAMP', \
                                help='Use to get the score at a specific time. Default is now.')
parser_history = subparsers.add_parser('history', help='Print Submit History.')
parser_history.add_argument('-t', '--top', action='store', dest='top', default=config.KOTH_DEFAULT_TOP_VALUE, \
                                type=int, metavar='NUM', \
                                help='Use to specify number of rows to display. Default is 30.')
parser_history.add_argument('--type', action='store', dest='type', default=None, \
                                type=int, metavar='NUM', \
                                help='Specify flag type to display (None=all, 1=Flag, 2=KingFlag).')
parser_stats = subparsers.add_parser('stats', help='Display game stats.')
parser_stats_action = parser_stats.add_argument_group("action")
parser_stats_option = parser_stats.add_argument_group("option")
parser_stats_action.add_argument('--general', action='store_true', dest='general', default=False, \
                                help='Print general stats about the game (flags qty, submit attempts, etc.)')
parser_stats_action.add_argument('--flagsSubmitCount', action='store_true', dest='flagsSubmitCount', default=False, \
                                help='Print number of successful submit per challenge.')
parser_stats_action.add_argument('--teamProgress', action='store_true', dest='teamProgress', default=False, \
                                help='Print all submitted flags of a specific team.')
parser_stats_action.add_argument('--flagProgress', action='store_true', dest='flagProgress', default=False, \
                                help='Print all teams who successfuly submitted a specific flag (TODO).')
parser_stats_option.add_argument('--flagFilter', action='store', dest='flagFilter', default='%', type=str, metavar='SQL FILTER', \
                                help='For --flagsSubmitCount only. Use to specify which flags to search for. Example: --flagFilter \'ssh%%\'')
parser_stats_option.add_argument('--id', action='store', dest='id', default=0, type=int, metavar='TEAM ID', \
                                help='For --teamProgress only. Use to specify which team to print progression for. Example: --id 14')
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
if DEBUG:
    print('[-] Arguments: ' + str(args))

# Special case: No exceptions handling for database security tests
if args.action == 'security':
    print("Testing database security")
    c = kothSecTest.kothSecTest()
    c.testSecurity()
    c.close()
    print('[+] Database security was tested successfuly')
    exit(0)

# DB Connect
try:
    c = kothAdmin.kothAdmin()
    c.setDebug(DEBUG)
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
    dump(e)
    exit(1)


# Run requested action
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
        elif args.list:
            print('Displaying teams informations (top '+str(args.top)+')')
            print(c.getTeamList(args.top))
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
        else:
            print('Displaying score (top '+str(args.top)+')')
            print(c.getFormatScore(args.top,args.ts))
    elif args.action == 'history':
        print('Displaying submit history(top '+str(args.top)+', type '+str(args.type)+')')
        print(c.getFormatSubmitHistory(args.top,args.type))
    elif args.action == 'stats':
        if args.general:
            print("Displaying games stats")
            print(c.getFormatGameStats())
        elif args.flagsSubmitCount:
            print("Displaying flags submit count")
            print(c.getFormatFlagsSubmitCount(args.flagFilter))
        elif args.teamProgress:
            print("Displaying team progression")
            print(c.getFormatTeamProgress(args.id))
        else:
            print("Displaying stats")
            print(c.getFormatGameStats())
    elif args.action == 'bench':
        print("Benchmarking database")
        c.benchmarkDB(args.reqNum)
    elif args.action == 'conbench':
        print("Benchmarking database connections")
        c.benchmarkDBCon(args.reqNum,args.reqCon)
    else:
        parser.print_help()
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
except postgresql.message.Message as m:
    print(m)
except Exception as e:
    print(e)
    dump(e)
else:
    print('[+] Job completed')

c.close()




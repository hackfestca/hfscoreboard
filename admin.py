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
parser_team_action.add_argument('-a', '--add', action='store', dest='add', default='', type=str, metavar='TEAM_INFO', \
                                help='Add a team. Format: NAME|SUBNET. Example: --add \'TeamName|172.29.23.0/24\'.')
parser_team_action.add_argument('-m', '--mod', action='store', dest='mod', default='', type=str, metavar='TEAM_INFO', \
                                 help='Modify a team. Use with --id to identity which team to update. \
                                       Format: NAME|SUBNET. Example: --mod \'TeamName|172.29.24.0/24\' --id 4')
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
parser_news_action.add_argument('-a', '--add', action='store', dest='add', default='', type=str, metavar='NEWS', \
                                help='Add a news. Example: --add \'Team A is dominating!\'.')
parser_news_action.add_argument('-m', '--mod', action='store', dest='mod', default='', type=str, 
                                help='Modify a news. Use with --id to identify which news to update. \
                                      Example: --mod \'This is another news\' --id 2.')
parser_news_action.add_argument('-l', '--list', action='store_true', dest='list', default=False, help='List news.')
parser_news_option.add_argument('-t', '--ts', action='store', dest='timestamp', metavar='TS', default='', type=str, \
                                help='For --add only. Used to specify when to display the news. \
                                      Date and time must be specified. \
                                      Example: --add \'Challenge D is unlocked!\' --ts \'2014-11-08 23:00\'.')
parser_news_option.add_argument('-i', '--id', action='store', dest='id', default=0, type=int, 
                                help='For --mod only. Used to identify which news to update. \
                                      Example: --mod \'Challenge D is unlocked!\' --id 1.')

parser_settings = subparsers.add_parser('settings', help='Manage game settings.')
parser_settings.add_argument('-s', '--gameStart', action='store', dest='gameStart', default='', type=str, \
                                 metavar='TS', 
                                help='Set a game start date/time. Example: --gameStart \'2014-11-08 10:00\'')
parser_settings.add_argument('-l', '--list', action='store_true', dest='list', default=False, help='List settings.')

parser_score = subparsers.add_parser('score', help='Print score table.')
parser_score.add_argument('-t', '--top', action='store', dest='top', default=config.KOTH_DEFAULT_TOP_VALUE, \
                                type=int, metavar='NUM', \
                                help='Use to specify number of rows to display. Default is 30.')
parser_score.add_argument('-s', '--ts', action='store', dest='ts', default=None, \
                                type=str, metavar='TIMESTAMP', \
                                help='Use to get the score at a specific time. Default is now.')
parser_history = subparsers.add_parser('history', help='Print Submit History.')
parser_history.add_argument('-t', '--top', action='store', dest='top', default=config.KOTH_DEFAULT_TOP_VALUE, \
                                type=int, metavar='NUM', \
                                help='Use to specify number of rows to display. Default is 30.')
parser_history.add_argument('--type', action='store', dest='type', default=None, \
                                type=int, metavar='NUM', \
                                help='Specify flag type to display (None=all, 1=Flag, 2=KingFlag).')
parser_graph = subparsers.add_parser('graph', help='Print score graph.')
parser_graph.add_argument('-t', '--top', action='store', dest='top', default=config.KOTH_DEFAULT_TOP_VALUE, \
                                type=int, metavar='NUM', \
                                help='Use to specify number of rows to display. Default is 30.')
parser_stats = subparsers.add_parser('stats', help='Display game stats.')
parser_bench = subparsers.add_parser('bench', help='Benchmark some db stored procedure.')
parser_conbench = subparsers.add_parser('conbench', help='Benchmark some db stored procedure using multiple connections.')
parser_matrix = subparsers.add_parser('matrix', help='Display the progress matrix.')
parser_matrix.add_argument('-t', '--top', action='store', dest='top', default=config.KOTH_DEFAULT_TOP_VALUE, \
                                type=int, metavar='NUM', \
                                help='Use to specify number of teams to display. Default is 30.')
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
            pass
        elif args.list:
            print("Displaying news")
            print(c.getFormatNews())
        else: 
            print('No subaction choosen')
            raise Exception('test')
    elif args.action == 'settings':
        if args.gameStart:
            c.setSetting('gameStartTs',args.gameStart,'timestamp')
        elif args.list:
            print("Displaying settings")
            print(c.getFormatSettings())
        else: 
            print('No subaction choosen')
            raise Exception('test')
    elif args.action == 'score':
        print('Displaying score (top '+str(args.top)+')')
        print(c.getFormatScore(args.top,args.ts))
    elif args.action == 'graph':
        print('Displaying graph (top '+str(args.top)+')')
        print(c.getGraphScore(args.top))
    elif args.action == 'history':
        print('Displaying submit history(top '+str(args.top)+', type '+str(args.type)+')')
        print(c.getFormatSubmitHistory(args.top,args.type))
    elif args.action == 'stats':
        print("Displaying stats")
        print(c.getFormatGameStats())
    elif args.action == 'bench':
        print("Benchmarking database")
        c.benchmarkDB()
    elif args.action == 'conbench':
        print("Benchmarking database connections")
        c.benchmarkDBCon()
    elif args.action == 'matrix':
        print("Displaying progression matrix")
        print(c.getFormatScoreProgress())
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
except postgresql.message.Message as m:
    print(m)
except Exception as e:
    print(e)
    dump(e)
else:
    print('[+] Job completed')

c.close()




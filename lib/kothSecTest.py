#!/usr/bin/python
# -*- coding: utf-8 -*-

'''
King of the hill admin class

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

import time
import config
import postgresql
import kothClient
import itertools

class kothSecTest(kothClient.kothClient):
    """

    """

    STATUS_HAS_ACCESS = 0
    STATUS_NO_ACCESS = 1

    _config = {}

    def __init__(self):
        super().__init__()
        self.initConfig()

    def initConfig(self):
        self._config = \
            { \
              'P_ACCESS': [ \
                            (self._oDB.proc('submitFlag(varchar)'),['asdf']), \
                            (self._oDB.proc('getScore(integer)'),[30]), \
                            (self._oDB.proc('getCatProgress()'),[]), \
                            (self._oDB.proc('getFlagProgress()'),[]), \
                            (self._oDB.proc('getValidNews()'),[]) \
                          ], \
              'P_NO_ACCESS': [ \
                               (self._oDB.proc('addTeam(varchar,varchar)'),['Team Name', '192.168.1.0/24']), \
                               (self._oDB.proc('addStatus(smallint,varchar,text)'),[4, 'Name', 'blabla']), \
                               (self._oDB.proc('addHost(varchar,text)'),['a', 'b']), \
                               (self._oDB.proc('addCategory(varchar,varchar,text)'),['a', 'b', 'c']), \
                               (self._oDB.proc('addRandomFlag(varchar,smallint,varchar,varchar,varchar,varchar,smallint,boolean,text,text)'),['a', 1, 'b', 'c', 'd', 'e', 1, True, 'f', 'g']), \
                               (self._oDB.proc('addKingFlagFromName(varchar,varchar,smallint)'),['a', 'b', 1]), \
                               (self._oDB.proc('submitFlagFromIp(varchar,varchar)'),['10.0.0.1', 'b']), \
                               (self._oDB.proc('addNews(varchar,varchar)'),['a','2014-03-03']), \
                               (self._oDB.proc('getAllKingFlags()'),[]), \
                               (self._oDB.proc('getKingFlagsFromHost(varchar)'),['asdf']), \
                               (self._oDB.proc('getKingFlagsFromName(varchar)'),['asdf']), \
                               (self._oDB.proc('addRandomKingFlagFromId(integer,integer)'),[1,2]), \
                               (self._oDB.proc('insertRandomData()'),[]), \
                               (self._oDB.proc('submitRandomFlag()'),[]) \
                             ] \
            }

    
    def testSecurity(self):
        for (f,a) in self._config['P_ACCESS']:
            try:
                if len(a) > 0:
                    ret = f(*a)
                else:
                    ret = f()
            except postgresql.exceptions.InsufficientPrivilegeError:
                print(f.name+'(): Player does not have access: ERROR')
            except postgresql.exceptions.PLPGSQLRaiseError as e:
                #print('[-] ('+str(e.code)+') '+e.message)
                print(f.name+'(): Player does have access: OK')
            else:
                print(f.name+'(): Player does have access: OK')

        for (f,a) in self._config['P_NO_ACCESS']:
            try:
                if len(a) > 0:
                    ret = f(*a)
                else:
                    ret = f()
                # An operation must be done to trigger a privilege error on itertools.chain
                # Operation here is list(ret)
                if type(ret) is itertools.chain:
                    ret2 = list(ret)
            except postgresql.exceptions.InsufficientPrivilegeError:
                print(f.name+'(): Player does not have access: OK')
            except Exception as e:
                print(e)
            else:
                print(f.name+'(): Player does have access: ERROR')


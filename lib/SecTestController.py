#!/usr/bin/python
# -*- coding: utf-8 -*-

'''
Security test controller class used by admin.py

@author: Martin Dubé
@organization: Hackfest Communications
@license: Modified BSD License
@contact: martin.dube@hackfest.ca

Copyright (c) 2014, Hackfest Communications
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

import config
import postgresql
import ClientController
import itertools

class SecTestController(ClientController.ClientController):
    """
    Security test controller class used by admin.py
    """

    STATUS_HAS_ACCESS = 0
    STATUS_NO_ACCESS = 1

    _config = {}

    def __init__(self):
        self._sUser = config.DB_PLAYER_USER
        self._sPass = config.DB_PLAYER_PASS
        self._sCrtFile = config.DB_PLAYER_CRT_FILE
        self._sKeyFile = config.DB_PLAYER_KEY_FILE
        super().__init__()
        try:
            self.initConfig()
        except postgresql.exceptions.UndefinedFunctionError:
            print('[-] There is a function missing')
            exit(0)

    def initConfig(self):
        self._config = \
            { \
              'P_ACCESS': [ \
                            (self._oDB.proc('submitFlagFromIp(varchar,varchar)'),['10.0.0.1', 'b']), \
                            (self._oDB.proc('getScore(integer,varchar,varchar)'),[30,None,None]), \
                            (self._oDB.proc('getCatProgressFromIp(varchar)'),['10.0.0.1']), \
                            (self._oDB.proc('getFlagProgressFromIp(varchar)'),['10.0.0.1']), \
                            (self._oDB.proc('getNews()'),[]) \
                          ], \
              'P_NO_ACCESS': [ \
                               (self._oDB.proc('addTeam(varchar,varchar)'),['Team Name', '192.168.1.0/24']), \
                               (self._oDB.proc('addStatus(integer,varchar,text)'),[4, 'Name', 'blabla']), \
                               (self._oDB.proc('addHost(varchar,varchar,text)'),['a', 'b', 'c']), \
                               (self._oDB.proc('addCategory(varchar,varchar,text,boolean)'),['a', 'b', 'c', None]), \
                               (self._oDB.proc('addRandomFlag(varchar,integer,varchar,varchar,integer,varchar,varchar,boolean,text,text,varchar,varchar)'),['name', 100, 'host', 'cat', 1, None, 'Author', True, 'desc', 'hint', 'updatecmd', 'monitorcmd']), \
                               (self._oDB.proc('addKingFlagFromName(varchar,varchar,integer)'),['a', 'b', 1]), \
                               (self._oDB.proc('addNews(varchar,varchar)'),['a','2014-03-03']), \
                               (self._oDB.proc('getAllKingFlags()'),[]), \
                               (self._oDB.proc('getKingFlagsFromHost(varchar)'),['asdf']), \
                               (self._oDB.proc('getKingFlagsFromName(varchar)'),['asdf']), \
                               (self._oDB.proc('addRandomKingFlagFromId(integer,integer)'),[1,2]), \
                               (self._oDB.proc('getScoreProgress(integer)'),[20]), \
                               (self._oDB.proc('getGameStats()'),[]), \
                               (self._oDB.proc('getRandomFlag()'),[]), \
                               (self._oDB.proc('getSettings()'),[]), \
                               (self._oDB.proc('startGame()'),[]), \
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
                print(f.name+'(): Player have access: OK')
            else:
                print(f.name+'(): Player have access: OK')

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
                print(f.name+'(): Player have access: ERROR')


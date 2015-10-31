#!/usr/bin/python
# -*- coding: utf-8 -*-

'''
Client controller class. Mostly an abstract class for other controllers.

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
from prettytable import PrettyTable 
import psycopg2
import time

class ClientController():
    """
    Client controller class. Mostly an abstract class for other controllers.
    """

    _bDebug = False
    '''
    @ivar: Determine if we run in debug mode or not.
    @type: Boolean
    '''

    _sUser = None
    '''
    @ivar: User name to use for authentication.
    @type: String
    '''

    _sPass = None
    '''
    @ivar: Password to use for authentication. If set, _sCrtFile and _sKeyFile must be None.
    @type: String
    '''

    _sCrtFile = None
    '''
    @ivar: Client certificate crt file to use for authentification. If set, _sPass must be None.
    @type: String
    '''

    _sKeyFile = None
    '''
    @ivar: Client certificate key file to use for authentification. If set, _sPass must be None.
    @type: String
    '''

    _oDB = None
    '''
    @ivar: Database connection object
    @type: tbd
    '''

    _oDBCursor = None

    def __init__(self):
        self._oDB = psycopg2.connect(\
                            user = self._sUser, \
                            password = self._sPass, \
                            host = config.DB_HOST, \
                            database = config.DB_NAME, \
                            connect_timeout = config.DB_CONNECT_TIMEOUT, \
                            sslmode = 'require',
                            sslcert = self._sCrtFile, \
                            sslkey = self._sKeyFile, \
                            sslrootcert = config.DB_SSL_ROOT_CA)
        self._oDB.set_isolation_level(psycopg2.extensions.ISOLATION_LEVEL_AUTOCOMMIT)
        self._oDB.autocommit = True     # Important for when submitFlag return an error (such as: invalid flag, already submit, etc.)
        self._oDBCursor = self._oDB.cursor()
        self._oDBCursor.execute("SET search_path = %s" % config.DB_SCHEMA)

#    def __del__(self):
#        if self._oDB:
#            self.close()

    def _exec(self, funcDef, *args):
        if self._bDebug:
            self._benchmark(funcDef,args)
        else:
            self._oDBCursor.callproc(funcDef,args)
        return self.fetchall()

    def exec(self, funcDef, *args):
        return self._exec(funcDef,*args)

    def fetchall(self):
        ret = self._oDBCursor.fetchall()
        if len(ret) == 1:
            if type(ret[0]) == str and len(ret[0]) == 1:
                return ret[0][0]
            else:
                return ret
        else:
            return ret

    def commit(self):
        self._oDB.commit()

    def _benchmark(self,f, args):
        t1 = time.time()
        ret = self._oDBCursor.callproc(f,args)
        t2 = time.time()
        print('[+] Debug: '+f+'() was executed in ' \
                  +str((t2-t1).__round__(4))+'ms')
        return ret

    def _benchmarkMany(self,nb,f,*args):
        t1 = time.time()
        if len(args) > 0:
            for i in range(0,nb):
                ret = f(*args)
        else:
            for i in range(0,nb):
                ret = f()
        t2 = time.time()
        print('[+] Debug: '+f.name+'() was executed '+str(nb)+' times in ' \
                  +str((t2-t1).__round__(4))+'ms')
        return ret

    def close(self):
        self._oDBCursor.close()
        self._oDB.close()

    def setDebug(self,debug):
        self._bDebug = debug
        
    def getScore(self,top=config.DEFAULT_TOP_VALUE,ts=None,cat=None):
        return self._exec('getScore',top,ts,cat)

    def getBMItemCategoryList(self):
        return self.exec('getBMItemCategoryList')
    
    def getBMItemStatusList(self):
        return self.exec('getBMItemStatusList')

    def getLotoHistory(self,top):
        return self.exec('getLotoHistory',top)

    def getLotoInfo(self):
        return self.exec('getLotoInfo')

    def getNewsList(self):
        return self.exec('getNewsList')

    def getFormatScore(self,top=config.DEFAULT_TOP_VALUE,ts=None,cat=None):
        title = ['ID','TeamName','FlagPts','KFlagPts','Total','Cash'] 
        score = self.getScore(top,ts,cat)
        x = PrettyTable(title)
        x.align['TeamName'] = 'l'
        x.padding_width = 1
        for row in score:
            x.add_row(row)
        return x.get_string()

    def getFormatNews(self):
        title = ['id','Release date&time', 'News']
        score = self.getNewsList()
        x = PrettyTable(title)
        x.align['Release date&time'] = 'l'
        x.align['News'] = 'l'
        x.padding_width = 1
        for row in score:
            x.add_row(row)
        return x.get_string()

    def getFormatBMItemCategoryList(self):
        title = ['Name', 'Description']
        score = self.getBMItemCategoryList()
        x = PrettyTable(title)
        x.align['Name'] = 'l'
        x.align['Description'] = 'l'
        x.padding_width = 1
        for row in score:
            x.add_row(row)
        return x.get_string()

    def getFormatBMItemStatusList(self):
        title = ['code','Name', 'Description']
        score = self.getBMItemStatusList()
        x = PrettyTable(title)
        x.align['Name'] = 'l'
        x.align['Description'] = 'l'
        x.padding_width = 1
        for row in score:
            x.add_row(row)
        return x.get_string()

    def getFormatLotoHistory(self,top):
        title = ['Src id','Src Wallet','Dst ID','Dst Wallet','Amount','Type','TS']
        info = self.getLotoHistory(top)
        x = PrettyTable(title)
        x.align['Src Wallet'] = 'l'
        x.align['Dst Wallet'] = 'l'
        x.align['Type'] = 'l'
        x.padding_width = 1
        for row in info:
            x.add_row(row)
        return x.get_string()

    def getFormatLotoInfo(self):
        title = ['Info', 'Value']
        score = self.getLotoInfo()
        x = PrettyTable(title)
        x.align['Info'] = 'l'
        x.align['Value'] = 'l'
        x.padding_width = 1
        for row in score:
            x.add_row(row)
        return x.get_string()


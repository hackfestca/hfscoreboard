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
import postgresql
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
    @type: postgresql
    '''

    def __init__(self):

        self._oDB = postgresql.open( \
                            user = self._sUser, \
                            password = self._sPass, \
                            host = config.DB_HOST, \
                            database = config.DB_NAME, \
                            connect_timeout = config.DB_CONNECT_TIMEOUT, \
                            sslmode = 'require',
                            sslcrtfile = self._sCrtFile, \
                            sslkeyfile = self._sKeyFile, \
                            sslrootcrtfile = config.DB_SSL_ROOT_CA)
        self._oDB.settings['search_path'] = config.DB_SCHEMA
#        self._oDB.settings['client_min_messages'] = 'NOTICE'

    def __del__(self):
        if self._oDB:
            self.close()

    def _benchmark(self,f, *args):
        t1 = time.time()
        if len(args) > 0:
            ret = f(*args)
        else:
            ret = f()
        t2 = time.time()
        print('[+] Debug: '+f.name+'() was executed in ' \
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

    def setDebug(self,debug):
        self._bDebug = debug
        
    def getScore(self,top=config.DEFAULT_TOP_VALUE,ts=None,cat=None):
        if self._bDebug:
            return self._benchmark(self._oDB.proc('getScore(integer,varchar,varchar)'),top,ts,cat)
        else:
            return self._oDB.proc('getScore(integer,varchar,varchar)')(top,ts,cat)

    def getFormatScore(self,top=config.DEFAULT_TOP_VALUE,ts=None,cat=None):
        title = ['ID','TeamName','FlagPts','FlagInstPts','Total'] 
        score = self.getScore(top,ts,cat)
        x = PrettyTable(title)
        x.align['TeamName'] = 'l'
        x.padding_width = 1
        for row in score:
            x.add_row(row)
        return x

    def getCatProgress(self):
        if self._bDebug:
            return self._benchmark(self._oDB.proc('getCatProgress()'))
        else:
            return self._oDB.proc('getCatProgress()')()

    def getFormatCatProgress(self):
        title = ['CatId','Category','DisplayName', 'Description','Score','Total','IsHidden'] 
        score = self.getCatProgress()
        x = PrettyTable(title)
        x.align['Category'] = 'l'
        x.align['DisplayName'] = 'l'
        x.align['Description'] = 'l'
        x.padding_width = 1
        for row in score:
            x.add_row(row)
        return x

    def getFlagProgress(self):
        if self._bDebug:
            return self._benchmark(self._oDB.proc('getFlagProgress()'))
        else:
            return self._oDB.proc('getFlagProgress()')()

    def getFormatFlagProgress(self):
        title = ['id','Name','Description','pts','CatId','CatName','isDone','DisplayInterval'] 
        score = self.getFlagProgress()
        x = PrettyTable(title)
        x.align['Name'] = 'l'
        x.align['Description'] = 'l'
        x.align['CatName'] = 'l'
        x.padding_width = 1
        for row in score:
            x.add_row(row)
        return x

    def getNews(self):
        if self._bDebug:
            return self._benchmark(self._oDB.proc('getNews()'))
        else:
            return self._oDB.proc('getNews()')()

    def getFormatNews(self):
        title = ['id','Release date&time', 'News']
        score = self.getNews()
        x = PrettyTable(title)
        x.align['Release date&time'] = 'l'
        x.align['News'] = 'l'
        x.padding_width = 1
        for row in score:
            x.add_row(row)
        return x

    def getTeamInfo(self):
        if self._bDebug:
            return self._benchmark(self._oDB.proc('getTeamInfo()'))
        else:
            return self._oDB.proc('getTeamInfo()')()

    def getFormatTeamInfo(self):
        title = ['Info','Value']
        info = self.getTeamInfo()
        x = PrettyTable(title)
        x.align['Info'] = 'l'
        x.align['Value'] = 'l'
        x.padding_width = 1
        for row in info:
            x.add_row(row)
        return x

    def close(self):
        self._oDB.close()


#!/usr/bin/python
# -*- coding: utf-8 -*-

'''
King of the hill client class

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

from prettytable import PrettyTable 
import postgresql
import config
import time

class kothClient():
    """

    """
    _bDebug = False
    _sSchema = 'scoreboard'
    _sDatabase = 'scoreboard'
    _sHost = 'db.hf'
    _sUser = None
    _sPass = None
    _sCrtFile = None
    _sKeyFile = None
    _sslRootCrt = 'certs/scoreboard-root-ca.crt'
    _iTimeout = 2
    _oDB = None

    def __init__(self):
        self._oDB = postgresql.open( \
                            user = self._sUser, \
                            password = self._sPass, \
                            host = self._sHost, \
                            database = self._sDatabase, \
                            connect_timeout = self._iTimeout, \
                            sslmode = 'require',
                            sslcrtfile = self._sCrtFile, \
                            sslkeyfile = self._sKeyFile, \
                            sslrootcrtfile = self._sslRootCrt)
        self._oDB.settings['search_path'] = self._sSchema
#        self._oDB.settings['search_path'] = self._sSchema
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
        
    def getScore(self,top=config.KOTH_DEFAULT_TOP_VALUE,ts=None,cat=None):
        if self._bDebug:
            return self._benchmark(self._oDB.proc('getScore(integer,varchar,varchar)'),top,ts,cat)
        else:
            return self._oDB.proc('getScore(integer,varchar,varchar)')(top,ts,cat)

    def getFormatScore(self,top=config.KOTH_DEFAULT_TOP_VALUE,ts=None,cat=None):
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


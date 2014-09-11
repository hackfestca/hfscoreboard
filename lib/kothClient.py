#!/usr/bin/python
# -*- coding: utf-8 -*-

'''
King of the hill client class

@author: Martin Dubé
@organization: Hackfest Communications
@license: GNU GENERAL PUBLIC LICENSE Version 3
@contact: martin.dube@hackfest.com

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
import time
import math
import config

class kothClient():
    """

    """
    _sVersion = '0.01'
    _bDebug = False
    _sSchema = 'scoreboard'
    _sDatabase = 'scoreboard'
    _sHost = '192.168.6.29'
    _sUser = 'player'
    _sPass = 'player'
    _sslRootCrt = 'certs/mon2k14-root-ca.crt'
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
                            sslrootcrtfile = self._sslRootCrt)
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

    def benchScore(self,callLimit=100):
        self._benchmarkMany(callLimit,self._oDB.proc('getScore(integer,varchar)'),config.KOTH_DEFAULT_TOP_VALUE,None)

    def getVersion(self):
        return self._sVersion

    def setDebug(self,debug):
        self._bDebug = debug
        
    def submitFlag(self,flagValue):
        if self._bDebug:
            return self._benchmark(self._oDB.proc('submitFlag(varchar)'),flagValue)
        else:
            return self._oDB.proc('submitFlag(varchar)')(flagValue)

    def submitRandomFlag(self):
        if self._bDebug:
            return self._benchmark(self._oDB.proc('submitRandomFlag()'))
        else:
            return self._oDB.proc('submitRandomFlag()')()

    def getScore(self,top=config.KOTH_DEFAULT_TOP_VALUE,ts=None):
        if self._bDebug:
            return self._benchmark(self._oDB.proc('getScore(integer,varchar)'),top,ts)
        else:
            return self._oDB.proc('getScore(integer,varchar)')(top,ts)

    def getFormatScore(self,top=config.KOTH_DEFAULT_TOP_VALUE,ts=None):
        title = ['ID','TeamName','FlagPts','FlagInstPts','Total'] 
        score = self.getScore(top,ts)
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
        title = ['CatId','Category','DisplayName', 'Description','Score','Total'] 
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

    def getValidNews(self):
        if self._bDebug:
            return self._benchmark(self._oDB.proc('getValidNews()'))
        else:
            return self._oDB.proc('getValidNews()')()

    def getFormatValidNews(self):
        title = ['id','Release date&time', 'News']
        score = self.getValidNews()
        x = PrettyTable(title)
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


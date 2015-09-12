#!/usr/bin/python
# -*- coding: utf-8 -*-

'''
Admin controller class used by admin.py.

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
import ClientController
import WebController
import threading
from prettytable import PrettyTable 
from io import StringIO
import csv

# Used for benchmark test only
class MyThread(threading.Thread):
    def __init__(self,con,reqNum):
        threading.Thread.__init__(self)
        self.con = con
        self.reqNum = reqNum
    def run(self):
        self.con.benchScoreProgress(self.reqNum)

class AdminController(ClientController.ClientController):
    ''' 
    Admin controller class used by admin.py
    '''

    def __init__(self):
        self._sUser = config.DB_ADMIN_USER
        self._sPass = config.DB_ADMIN_PASS
        self._sCrtFile = config.DB_ADMIN_CRT_FILE
        self._sKeyFile = config.DB_ADMIN_KEY_FILE
        super().__init__()
    
    def benchmarkDB(self,reqNum=config.BENCH_DEFAULT_REQ_NUM):
        print('Testing getScore()')
        self._benchmarkMany(reqNum,self._oDB.proc('getScore(integer,varchar,varchar)'),config.DEFAULT_TOP_VALUE,None,None)
        print('Testing getNews()')
        self._benchmarkMany(reqNum,self._oDB.proc('getNews()'))

    def benchmarkDBCon(self,reqNum=config.BENCH_DEFAULT_REQ_NUM,reqCon=config.BENCH_DEFAULT_CON_NUM):
        aThreads = []

        print('Opening %i connections' % reqCon)
        for i in range(0,reqCon):
            if i%10 == 0 and i != 0:
                print('Nb of connections opened: %i' % i)
            aThreads.append(MyThread(WebController.WebController(),reqNum))
        
        for i in range(0,reqCon):
            t = aThreads[i]
            print('Running getScoreProgress() %i times on instance #%i' % (reqNum,i))
            t.start()

        # Wait for all threads to complete
        for t in aThreads:
            t.join()

    def addTeam(self,name,net):
        if self._bDebug:
            return self._benchmark(self._oDB.proc('addTeam(varchar,varchar)'),name,net)
        else:
            return self._oDB.proc('addTeam(varchar,varchar)')(name,net)

    def modTeam(self,id,name,net):
        if self._bDebug:
            return self._benchmark(self._oDB.proc('modTeam(integer,varchar,varchar)'),id,name,net)
        else:
            return self._oDB.proc('modTeam(integer,varchar,varchar)')(id,name,net)

    def listTeams(self,top=config.DEFAULT_TOP_VALUE):
        if self._bDebug:
            return self._benchmark(self._oDB.proc('listTeams(integer)'),top)
        else:
            return self._oDB.proc('listTeams(integer)')(top)

    def rewardTeam(self,id,name,pts):
        if self._bDebug:
            return self._benchmark(self._oDB.proc('rewardTeam(integer,varchar,integer)'),id,name,pts)
        else:
            return self._oDB.proc('rewardTeam(integer,varchar,integer)')(id,name,pts)

    def getTeamList(self,top=config.DEFAULT_TOP_VALUE):
        title = ['ID','Name','Net','FlagPts','FlagInstPts','Total'] 
        score = self.listTeams(top)
        x = PrettyTable(title)
        x.align['Name'] = 'l'
        x.align['Net'] = 'l'
        x.padding_width = 1
        for row in score:
            x.add_row(row)
        return x

    def addNews(self,desc,ts):
        if self._bDebug:
            return self._benchmark(self._oDB.proc('addNews(varchar,varchar)'),desc,ts)
        else:
            return self._oDB.proc('addNews(varchar,varchar)')(desc,ts)

    def listFlags(self,top=config.DEFAULT_TOP_VALUE):
        if self._bDebug:
            return self._benchmark(self._oDB.proc('listFlags(integer)'),top)
        else:
            return self._oDB.proc('listFlags(integer)')(top)

    def getFlagList(self,top=config.DEFAULT_TOP_VALUE):
        title = ['ID','Name','Pts','Cash','Category','Status','Type','TypeExt','Author','Display Int.','Description'] 
        score = self.listFlags(top)
        x = PrettyTable(title)
        x.align['Name'] = 'l'
        x.align['Category'] = 'l'
        x.align['Author'] = 'l'
        x.align['Description'] = 'l'
        x.padding_width = 1
        for row in score:
            x.add_row(row)
        return x

    def getGraphScore(self,top=config.DEFAULT_TOP_VALUE):
        try:
            from ascii_graph import Pyasciigraph
        except ImportError:
            print('ascii_graph module is needed for this function. (pip install ascii_graph)')

        score = (row[1::3] for row in list(self.getScore(top,None)))
        graph = Pyasciigraph()
        return '\n'.join(graph.graph('', score))

    def getFlagsSubmitCount(self,nameFilter):
        if self._bDebug:
            return self._benchmark(self._oDB.proc('getFlagsSubmitCount(varchar)'),nameFilter)
        else:
            return self._oDB.proc('getFlagsSubmitCount(varchar)')(nameFilter)

    def getFormatFlagsSubmitCount(self,nameFilter):
        title = ['Flag','Submit Count']
        info = self.getFlagsSubmitCount(nameFilter)
        x = PrettyTable(title)
        x.align['Flag'] = 'l'
        x.align['Submit Count'] = 'l'
        x.padding_width = 1
        for row in info:
            x.add_row(row)
        return x

    def getGameStats(self):
        if self._bDebug:
            return self._benchmark(self._oDB.proc('getGameStats()'))
        else:
            return self._oDB.proc('getGameStats()')()

    def getFormatGameStats(self):
        title = ['Info','Value']
        info = self.getGameStats()
        x = PrettyTable(title)
        x.align['Info'] = 'l'
        x.align['Value'] = 'l'
        x.padding_width = 1
        for row in info:
            x.add_row(row)
        return x

    def getTeamProgress(self,teamId):
        if self._bDebug:
            return self._benchmark(self._oDB.proc('getTeamProgress(integer)'),teamId)
        else:
            return self._oDB.proc('getTeamProgress(integer)')(teamId)

    def getFormatTeamProgress(self,teamId):
        title = ['Flag','isDone','Submit timestamp']
        info = self.getTeamProgress(teamId)
        x = PrettyTable(title)
        x.align['Flag'] = 'l'
        x.align['Submit timestamp'] = 'l'
        x.padding_width = 1
        for row in info:
            x.add_row(row)
        return x

    def getFlagProgress(self,flagName):
        if self._bDebug:
            return self._benchmark(self._oDB.proc('getFlagProgress(varchar)'),flagName)
        else:
            return self._oDB.proc('getFlagProgress(varchar)')(flagName)

    def getFormatFlagProgress(self,flagName):
        title = ['Team','isDone','Submit timestamp']
        info = self.getFlagProgress(flagName)
        x = PrettyTable(title)
        x.align['Team'] = 'l'
        x.align['Submit timestamp'] = 'l'
        x.padding_width = 1
        for row in info:
            x.add_row(row)
        return x

    def getScoreProgress(self):
        if self._bDebug:
            return self._benchmark(self._oDB.proc('getScoreProgress(integer)'),None)
        else:
            return self._oDB.proc('getScoreProgress(integer)')(None)

    def getFormatScoreProgress(self):
        info = self.getScoreProgress()
        x = PrettyTable()
        x.padding_width = 1
        for row in info:
            x.add_row(row)
        return x

    def startGame(self):
        if self._bDebug:
            return self._benchmark(self._oDB.proc('startGame()'))
        else:
            return self._oDB.proc('startGame()')()

    def setSetting(self,attr,value,type):
        if self._bDebug:
            return self._benchmark(self._oDB.proc('setSetting(text,text,varchar)'),attr,value,type)
        else:
            return self._oDB.proc('setSetting(text,text,varchar)')(attr,value,type)

    def getSettings(self):
        if self._bDebug:
            return self._benchmark(self._oDB.proc('getSettings()'))
        else:
            return self._oDB.proc('getSettings()')()

    def getFormatSettings(self):
        title = ['Key', 'Value']
        settings = self.getSettings()
        x = PrettyTable(title)
        x.padding_width = 1
        for row in settings:
            x.add_row(row)
        return x

    def getSubmitHistory(self,top=config.DEFAULT_TOP_VALUE,type=None):
        if self._bDebug:
            return self._benchmark(self._oDB.proc('getSubmitHistory(integer,integer)'),top,type)
        else:
            return self._oDB.proc('getSubmitHistory(integer,integer)')(top,type)

    def getFormatSubmitHistory(self,top=config.DEFAULT_TOP_VALUE,type=None):
        title = ['Timestamp', 'TeamName', 'FlagName', 'Pts', 'Category', 'Type']
        history = self.getSubmitHistory(top,type)
        x = PrettyTable(title)
        x.padding_width = 1
        for row in history:
            x.add_row(row)
        return x

    def getCsvScoreProgress(self):
        data = StringIO()
        csvh = csv.writer(data, delimiter=',', quotechar='"', quoting=csv.QUOTE_MINIMAL)
        teams = self.getScore(15)
        newTeams = [x[1] for x in teams]
        score = list(self.getScoreProgress())
        newScore = [[[x,str(x)][type(x) == int] for x in y] for y in score]

        # Write header
        csvh.writerow(['Time'] + newTeams)

        # Write content
        for line in newScore:
            csvh.writerow([line[0].strftime("%Y-%m-%d %H:%M:%S")] + line[1:])

        return data.getvalue()

#!/usr/bin/python
# -*- coding: utf-8 -*-

'''
Admin controller class used by admin.py.

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

import config
import ClientController
import WebController
import threading
from prettytable import PrettyTable 
from io import StringIO
import csv
from time import sleep
from datetime import datetime
#from termcolor import colored

# Used for benchmark test only
class MyThread(threading.Thread):
    def __init__(self,con,reqNum):
        threading.Thread.__init__(self)
        self.con = con
        self.reqNum = reqNum
    def run(self):
        self.con.benchScoreProgress(self.reqNum)

class colors:
    '''Colors class:
        reset all colors with colors.reset
        two subclasses fg for foreground and bg for background.
        use as colors.subclass.colorname.
        i.e. colors.fg.red or colors.bg.green
        also, the generic bold, disable, underline, reverse, strikethrough,
        and invisible work with the main class
        i.e. colors.bold
    '''
    reset='\033[0m'
    bold='\033[01m'
    disable='\033[02m'
    underline='\033[04m'
    reverse='\033[07m'
    strikethrough='\033[09m'
    invisible='\033[08m'
    class fg:
        black='\033[30m'
        red='\033[31m'
        green='\033[32m'
        orange='\033[33m'
        blue='\033[34m'
        purple='\033[35m'
        cyan='\033[36m'
        lightgrey='\033[37m'
        darkgrey='\033[90m'
        lightred='\033[91m'
        lightgreen='\033[92m'
        yellow='\033[93m'
        lightblue='\033[94m'
        pink='\033[95m'
        lightcyan='\033[96m'
    class bg:
        black='\033[40m'
        red='\033[41m'
        green='\033[42m'
        orange='\033[43m'
        blue='\033[44m'
        purple='\033[45m'
        cyan='\033[46m'
        lightgrey='\033[47m'

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
        self._benchmarkMany(reqNum,'getScore',[config.DEFAULT_TOP_VALUE,None,None])
        print('Testing getNewsList()')
        self._benchmarkMany(reqNum,'getNewsList',[])

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
        return self._exec('addTeam',name,net)

    def modTeam(self,id,name,net):
        return self._exec('modTeam',id,name,net)

    def getTeamList(self,grep=None,top=config.DEFAULT_TOP_VALUE):
        return self._exec('listTeams',grep,top)

    def rewardTeam(self,id,name,pts):
        return self._exec('rewardTeam',id,name,pts)

    def launderMoney(self,id,cash):
        return self.exec('launderMoneyFromTeamid',id,cash)

    def getTeamsVariables(self,grep,top=config.DEFAULT_TOP_VALUE):
        return self.exec('getTeamsVariables',grep,top)

    def addNews(self,desc,ts):
        return self.exec('addNews',desc,ts)

    def modNews(self,id,desc,ts):
        return self.exec('modNews',id,desc,ts)

    def checkFlag(self,flagValue):
        return self.exec('checkFlag',flagValue)

    def getFlagList(self,top=config.DEFAULT_TOP_VALUE):
        return self.exec('getFlagList',top)

    def getFlagsSubmitCount(self,nameFilter):
        return self.exec('getFlagsSubmitCount',nameFilter)

    def addBMItem(self,name,amount,qty,disp,desc,data):
        category = 'admin'
        status = 1
        wallet = 1
        return self.exec('addBMItem',\
                          name,category,status,wallet,amount,qty,disp,desc,data)

    def modBMItem(self,id,name,amount,qty,disp,desc):
        return self.exec('modBMItem',\
                          id,name,amount,qty,disp,desc)

    def getBMItemInfo(self,id):
        return self.exec('getBMItemInfo',id)

    def getBMItemLink(self,id):
        return self.exec('getBMItemLink',id)

    def reviewBMItem(self,id,approve,rating,comments):
        return self.exec('reviewBMItem',id,approve,rating,comments)

    def getBMItemList(self,top):
        return self.exec('getBMItemList',top)

    def setBMItemStatus(self,id,status):
        return self.exec('setBMItemStatus',id,status)

    def getLotoHistory(self,top):
        return self.exec('getLotoHistory',top)

    def getTransactionHistory(self,top):
        return self.exec('getTransactionHistory',top)

    def startGame(self):
        return self.exec('startGame')

    def setSetting(self,attr,value,type):
        return self.exec('setSetting',attr,value,type)

    def getSettings(self):
        return self.exec('getSettings')

    def getGameStats(self):
        return self.exec('getGameStats')

    def getTeamProgress(self,teamId):
        return self.exec('getTeamProgress',teamId)

    def getFlagProgress(self,flagName):
        return self.exec('getFlagProgress',flagName)

    def getFlagTypeList(self):
        return self.exec('getFlagTypeList')

    def getScoreProgress(self):
        return self.exec('getScoreProgress',None)

    def getSubmitHistory(self,top=config.DEFAULT_TOP_VALUE,type=None):
        return self.exec('getSubmitHistory',top,type)

    def getEvents(self,lastUpdate=None,facility=None,severity=None,grep=None,top=config.DEFAULT_TOP_VALUE):
        return self.exec('getEvents',\
                            lastUpdate,facility,severity,grep,top)

    def getFormatTeamList(self,grep=None,top=config.DEFAULT_TOP_VALUE):
        title = ['ID', 'Num','Name','Net','FlagPts','KFlagPts','Total','Cash'] 
        score = self.getTeamList(grep,top)
        x = PrettyTable(title)
        x.align['Name'] = 'l'
        x.align['Net'] = 'l'
        x.padding_width = 1
        for row in score:
            x.add_row(row)
        return x.get_string()

    def getFormatTeamsVariables(self,grep=None,top=config.DEFAULT_TOP_VALUE):
        title = ['Team Name','Name','Value']
        score = self.getTeamsVariables(grep,top)
        x = PrettyTable(title)
        x.align['Team Name'] = 'l'
        x.align['Name'] = 'l'
        x.align['Value'] = 'l'
        x.padding_width = 1
        for row in score:
            x.add_row(row)
        return x.get_string()

    def getFormatFlagList(self,top=config.DEFAULT_TOP_VALUE):
        title = ['ID','Name','Pts','Cash','Category','Status','Type','TypeExt','Author','Display Int.','Description'] 
        score = self.getFlagList(top)
        x = PrettyTable(title)
        x.align['Name'] = 'l'
        x.align['Category'] = 'l'
        x.align['Author'] = 'l'
        x.align['Description'] = 'l'
        x.padding_width = 1
        x.max_width = 40
        for row in score:
            x.add_row(row)
        return x.get_string()

    def getGraphScore(self,top=config.DEFAULT_TOP_VALUE):
        try:
            from ascii_graph import Pyasciigraph
        except ImportError:
            print('ascii_graph module is needed for this function. (pip install ascii_graph)')

        score = (row[1::3] for row in list(self.getScore(top,None)))
        graph = Pyasciigraph()
        return '\n'.join(graph.graph('', score))

    def getFormatFlagsSubmitCount(self,nameFilter):
        title = ['Flag','Submit Count']
        info = self.getFlagsSubmitCount(nameFilter)
        x = PrettyTable(title)
        x.align['Flag'] = 'l'
        x.align['Submit Count'] = 'l'
        x.padding_width = 1
        for row in info:
            x.add_row(row)
        return x.get_string()

    def getFormatBMItemInfo(self,id):
        title = ['Info','Value']
        info = self.getBMItemInfo(id)
        x = PrettyTable(title)
        x.align['Info'] = 'l'
        x.align['Value'] = 'l'
        x.padding_width = 1
        for row in info:
            x.add_row(row)
        return x.get_string()

    def getFormatBMItemList(self,top):
        title = ['id','name','description','category','status','rating','owner','cost','qty']
        info = self.getBMItemList(top)
        x = PrettyTable(title)
        x.align['name'] = 'l'
        x.align['description'] = 'l'
        x.align['category'] = 'l'
        x.align['status'] = 'l'
        x.max_width = 40
        x.padding_width = 1
        for row in info:
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

    def getFormatTransactionHistory(self,top):
        title = ['Src Wallet','Dst Wallet','Amount','Type','TS']
        info = self.getTransactionHistory(top)
        x = PrettyTable(title)
        x.align['Src Wallet'] = 'l'
        x.align['Dst Wallet'] = 'l'
        x.align['Type'] = 'l'
        x.padding_width = 1
        for row in info:
            x.add_row(row)
        return x.get_string()

    def getFormatGameStats(self):
        title = ['Info','Value']
        info = self.getGameStats()
        x = PrettyTable(title)
        x.align['Info'] = 'l'
        x.align['Value'] = 'l'
        x.padding_width = 1
        for row in info:
            x.add_row(row)
        return x.get_string()

    def getFormatTeamProgress(self,teamId):
        title = ['Flag','isDone','Submit timestamp']
        info = self.getTeamProgress(teamId)
        x = PrettyTable(title)
        x.align['Flag'] = 'l'
        x.align['Submit timestamp'] = 'l'
        x.padding_width = 1
        x.max_width = 40
        for row in info:
            x.add_row(row)
        return x.get_string()

    def getFormatFlagProgress(self,flagName):
        title = ['Team','isDone','Submit timestamp']
        info = self.getFlagProgress(flagName)
        x = PrettyTable(title)
        x.align['Team'] = 'l'
        x.align['Submit timestamp'] = 'l'
        x.padding_width = 1
        x.max_width = 40
        for row in info:
            x.add_row(row)
        return x.get_string()

    def getFormatScoreProgress(self):
        info = self.getScoreProgress()
        x = PrettyTable()
        x.padding_width = 1
        x.max_width = 40
        for row in info:
            x.add_row(row)
        return x.get_string()

    def getFormatSettings(self):
        title = ['Key', 'Value']
        settings = self.getSettings()
        x = PrettyTable(title)
        x.align['Key'] = 'l'
        x.padding_width = 1
        x.max_width = 40
        for row in settings:
            x.add_row(row)
        return x.get_string()

    def getFormatSubmitHistory(self,top=config.DEFAULT_TOP_VALUE,type=None):
        title = ['Timestamp', 'TeamName', 'FlagName', 'Pts', 'Category', 'Type']
        history = self.getSubmitHistory(top,type)
        x = PrettyTable(title)
        x.padding_width = 1
        for row in history:
            x.add_row(row)
        return x.get_string()

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

    def getFormatEvents(self,lastUpdate=None,facility=None,severity=None,grep=None,top=config.DEFAULT_TOP_VALUE):
        title = ['Title', 'Facility', 'Severity', 'Ts']
        events = self.getEvents(lastUpdate,facility,severity,grep,top)
        x = PrettyTable(title)
        x.align['Title'] = 'l'
        x.padding_width = 1
        x.max_width = 80
        for row in events:
            x.add_row(row)
        return x.get_string()

    def printLiveFormatEvents(self,lastUpdate=None,facility=None,severity=None,grep=None,top=300,refresh=10):
        formatStr = "%s%s %s%s %s%s %s%s"
        events = self.getEvents(lastUpdate,facility,severity,grep,top)
        for row in events:
            print(formatStr % (colors.fg.green,row[3],
                               colors.fg.yellow,row[1],
                               colors.fg.orange,row[2],
                               colors.reset,row[0]))
        lastUpdate = datetime.now()
        sleep(refresh)

        while True:
            events = list(self.getEvents(lastUpdate,facility,severity,grep,top))
            if len(events) > 0:
                for row in events:
                    print(formatStr % (colors.fg.green,row[3],
                                       colors.fg.yellow,row[1],
                                       colors.fg.orange,row[2],
                                       colors.reset,row[0]))
                    lastUpdate = datetime.now()
            sleep(refresh)

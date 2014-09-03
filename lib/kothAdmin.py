#!/usr/bin/python
# -*- coding: utf-8 -*-

'''
King of the hill admin class

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

import config
import kothClient
from prettytable import PrettyTable 

class kothAdmin(kothClient.kothClient):
    """

    """
    _sVersion = '0.01'
    _sUser = 'martin'
    _sPass = 'h9N)kv1*H!3(|<eASR1^]Iwql;fsDIDc6h.?o\,IS[v?4:~}J0'

    def __init__(self):
        super().__init__()
    
    def benchmarkDB(self):
        print('Testing getScore()')
        self._benchmarkMany(100,self._oDB.proc('getScore(integer)'),config.KOTH_DEFAULT_TOP_VALUE)
        print('Testing getValidNews()')
        self._benchmarkMany(100,self._oDB.proc('getValidNews()'))

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

    def listTeams(self,top=config.KOTH_DEFAULT_TOP_VALUE):
        if self._bDebug:
            return self._benchmark(self._oDB.proc('listTeams(integer)'),top)
        else:
            return self._oDB.proc('listTeams(integer)')(top)

    def getTeamList(self,top=config.KOTH_DEFAULT_TOP_VALUE):
        title = ['ID','Name','Net','FlagPts','FlagInstPts','Total'] 
        score = self.listTeams(top)
        x = PrettyTable(title)
        x.align['Name'] = 'l'
        x.align['Net'] = 'l'
        x.padding_width = 1
        for row in score:
            x.add_row(row)
        return x

    def getGraphScore(self,top=config.KOTH_DEFAULT_TOP_VALUE):
        try:
            from ascii_graph import Pyasciigraph
        except ImportError:
            print('ascii_graph module is needed for this function. (pip install ascii_graph)')

        score = (row[1::3] for row in list(self.getScore(top)))
        graph = Pyasciigraph()
        return '\n'.join(graph.graph('', score))

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

    def getJsDataScoreProgress(self,varname='data'):
        s ="var data = google.visualization.arrayToDataTable([\n"
        teams = self.getScore(10)
        newTeams = [x[1] for x in teams]
        score = list(self.getScoreProgress())
        newScore = [[[x,str(x)][type(x) == int] for x in y] for y in score]
        s += '[\'Time\',\'' + '\', \''.join(newTeams) + '\']' + "\n"
        for line in newScore:
            s += ',[\'' + line[0].strftime("%H:%M") + '\',' + ','.join(line[1:]) + ']' + "\n"
        s += "]);"
        return s

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

    

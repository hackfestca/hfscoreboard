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

import kothClient
import config

class kothScoreboard(kothClient.kothClient):
    """

    """
    _sUser = 'scoreboard'
    _sPass = None
    _sCrtFile = 'certs/cli.psql.scoreboard.scoreboard.crt'
    _sKeyFile = 'certs/cli.psql.scoreboard.scoreboard.key'

    def __init__(self):
        super().__init__()

    def benchScore(self,callLimit=100):
        self._benchmarkMany(callLimit,self._oDB.proc('getScore(integer,varchar,varchar)'),config.KOTH_DEFAULT_TOP_VALUE,None,None)

    def benchScoreProgress(self,callLimit=100):
        self._benchmarkMany(callLimit,self._oDB.proc('getScoreProgress(integer)'),None)

    def submitFlagFromIp(self,playerIp,flagValue):
        if self._bDebug:
            return self._benchmark(self._oDB.proc('submitFlagFromIp(varchar,varchar)'),playerIp,flagValue)
        else:
            return self._oDB.proc('submitFlagFromIp(varchar,varchar)')(playerIp,flagValue)

    def getCatProgressFromIp(self,playerIp):
        if self._bDebug:
            return self._benchmark(self._oDB.proc('getCatProgressFromIp(varchar)'),playerIp)
        else:
            return self._oDB.proc('getCatProgressFromIp(varchar)')(playerIp)

    def getFlagProgressFromIp(self,playerIp):
        if self._bDebug:
            return self._benchmark(self._oDB.proc('getFlagProgressFromIp(varchar)'),playerIp)
        else:
            return self._oDB.proc('getFlagProgressFromIp(varchar)')(playerIp)

    def getScoreProgress(self):
        if self._bDebug:
            return self._benchmark(self._oDB.proc('getScoreProgress(integer)'),None)
        else:
            return self._oDB.proc('getScoreProgress(integer)')(None)

    def getTeamInfo(self,playerIp):
        if self._bDebug:
            return self._benchmark(self._oDB.proc('getTeamInfoFromIp(varchar)'),playerIp)
        else:
            return self._oDB.proc('getTeamInfoFromIp(varchar)')(playerIp)

    def getJsDataScoreProgress(self,varname='data'):
        s = "[\n"
        teams = self.getScore(15)
        newTeams = [x[1] for x in teams]
        score = list(self.getScoreProgress())
        newScore = [[[x,str(x)][type(x) == int] for x in y] for y in score]
        s += "['Time', '{}']\n".format("', '".join(newTeams))
        for line in newScore:
            s += ",['{}', {}]\n".format(
                line[0].strftime("%H:%M"),
                ','.join(line[1:])
                )
        s += "]"
        return s

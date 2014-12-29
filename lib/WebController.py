#!/usr/bin/python
# -*- coding: utf-8 -*-

'''
Web controller class used by scoreboard.py

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

import ClientController
import config

class WebController(ClientController.ClientController):
    """
    Web controller class used by scoreboard.py
    """

    def __init__(self):
        # Prevent overwrite for inherited classes
        if self._sUser is None:
            self._sUser = config.DB_WEB_USER
            self._sPass = config.DB_WEB_PASS
            self._sCrtFile = config.DB_WEB_CRT_FILE
            self._sKeyFile = config.DB_WEB_KEY_FILE
        super().__init__()

    def benchScore(self,callLimit=config.BENCH_DEFAULT_REQ_NUM):
        self._benchmarkMany(callLimit,self._oDB.proc('getScore(integer,varchar,varchar)'),config.DEFAULT_TOP_VALUE,None,None)

    def benchScoreProgress(self,callLimit=config.BENCH_DEFAULT_REQ_NUM):
        self._benchmarkMany(callLimit,self._oDB.proc('getScoreProgress(integer)'),None)

    def submitFlagFromIp(self,playerIp,flagValue):
        if self._bDebug:
            self._benchmark(self._oDB.proc('logSubmit(varchar,varchar)'),playerIp,flagValue)
            return self._benchmark(self._oDB.proc('submitFlagFromIp(varchar,varchar)'),playerIp,flagValue)
        else:
            self._oDB.proc('logSubmit(varchar,varchar)')(playerIp,flagValue)
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
#!/usr/bin/python
# -*- coding: utf-8 -*-

'''
Web controller class used by scoreboard.py

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
import ClientController
import config
from io import StringIO
import csv 
import html # For html entities

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
        self._benchmarkMany(callLimit,'getScore',[config.DEFAULT_TOP_VALUE,None,None])

    def benchScoreProgress(self,callLimit=config.BENCH_DEFAULT_REQ_NUM):
        self._benchmarkMany(callLimit,'getScoreProgress',[None])

    def submitFlag(self,flagValue,teamId,playerIp):
        self.exec('logSubmit',flagValue,teamId,playerIp)
        return self.exec('submitFlag',flagValue,teamId,playerIp)

    def submitFlagFromIp(self,flagValue,playerIp):
        self.exec('logSubmit',flagValue,None,playerIp)
        return self.exec('submitFlagFromIp',flagValue,playerIp)

    def getBMItemDataFromIp(self,privateId,playerIp):
        return self.exec('getBMItemDataFromIp',privateId,playerIp)

    def getCatProgress(self,teamId):
        return self.exec('getCatProgress',teamId)

    def getCatProgressFromIp(self,playerIp):
        return self.exec('getCatProgressFromIp',playerIp)

    def getFlagProgress(self,teamId):
        return self.exec('getFlagProgress',teamId)

    def getFlagProgressFromIp(self,playerIp):
        return self.exec('getFlagProgressFromIp',playerIp)

    def getScoreProgress(self):
        return self.exec('getScoreProgress',None)

    def getTeamInfo(self,teamId):
        return self.exec('getTeamInfo',teamId)

    def getTeamInfoFromIp(self,playerIp):
        return self.exec('getTeamInfoFromIp',playerIp)

    def getTeamSecrets(self,teamId):
        return self.exec('getTeamSecrets',teamId)

    def getTeamSecretsFromIp(self,playerIp):
        return self.exec('getTeamSecretsFromIp',playerIp)

    def registerTeam(self,name,pwd1,pwd2,loc):
        return self.exec('registerTeam',name,pwd1,pwd2,loc)

    def loginTeam(self,name,pwd):
        return self.exec('loginTeam',name,pwd)

    def getJsDataScoreProgress(self):
        s = "[\n"
        teams = self.getScore(8)
        newTeams = [x[1] for x in teams]
        score = list(self.getScoreProgress())
        newScore = [[[x,str(x)][type(x) == int] for x in y] for y in score]
        s += "['Time', '{}']\n".format("', '".join(newTeams))
        for line in newScore:
            s += ",['{}', {}]\n".format(
                line[0].strftime("%Y-%m-%d %H:%M"),
                ','.join(line[1:])
                )
        s += "]"
        return s

    def getCsvScoreProgress(self):
        data = StringIO()
        csvh = csv.writer(data, delimiter=',',
                          quotechar='"',doublequote=False,escapechar='\\',
                          quoting=csv.QUOTE_MINIMAL)
        score = list(self.getScoreProgress())
        newScore = [[[x,str(x)][type(x) == int] for x in y] for y in score]
        team_ct = len(score[0])-1
        teams = self.getScore(team_ct)
        newTeams = [x[1] for x in teams]

        # Write header
        csvh.writerow(['Time'] + newTeams)

        # Write content
        for line in newScore:
            csvh.writerow([line[0].strftime("%Y/%m/%d %H:%M:%S")] + line[1:])

        return data.getvalue()


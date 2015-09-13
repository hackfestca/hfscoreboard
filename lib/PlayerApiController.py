#!/usr/bin/python
# -*- coding: utf-8 -*-

'''
Player API controller class used by player-api.py

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
import WebController
from prettytable import PrettyTable 

class PlayerApiController(WebController.WebController):
    """
    Player API controller class used by player-api.py
    """

    def __init__(self):
        self._sUser = config.DB_PLAYER_USER
        self._sPass = config.DB_PLAYER_PASS
        self._sCrtFile = config.DB_PLAYER_CRT_FILE
        self._sKeyFile = config.DB_PLAYER_KEY_FILE
        super().__init__()
    
    def getFormatCatProgressFromIp(self,playerIp):
        keepCols = [2,3,4,5]
        title = ['Category','Description','Score','Category Total'] 
        score = self.getCatProgressFromIp(playerIp)
        newScore = [[row[i] for i in keepCols] for row in score]
        x = PrettyTable(title)
        x.align['Category'] = 'l'
        x.align['Description'] = 'l'
        x.padding_width = 1
        for row in newScore:
            x.add_row(row)
        return x

    def getFormatFlagProgressFromIp(self,playerIp):
        keepCols = [1,2,5,7,8,9]
        #title = ['id','Name','Description','pts','FlagPts','DisplayPts','CatId','CatName','isDone','Author','DisplayInterval'] 
        title = ['Name','Description','Score','Category','isDone','Author']
        score = list(self.getFlagProgressFromIp(playerIp))
        newScore = [[row[i] for i in keepCols] for row in score]
        x = PrettyTable(title)
        x.align['Name'] = 'l'
        x.align['Description'] = 'l'
        x.align['Category'] = 'l'
        x.align['isDone'] = 'l'
        x.align['Author'] = 'l'
        x.padding_width = 1
        for row in newScore:
            x.add_row(row)
        return x

    def getFormatTeamInfoFromIp(self,playerIp):
        title = ['Info','Value']
        info = self.getTeamInfo(playerIp)
        x = PrettyTable(title)
        x.align['Info'] = 'l'
        x.align['Value'] = 'l'
        x.padding_width = 1
        for row in info:
            x.add_row(row)
        return x


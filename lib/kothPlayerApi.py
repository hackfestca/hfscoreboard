#!/usr/bin/python
# -*- coding: utf-8 -*-

'''
King of the hill admin class

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

import config
import kothScoreboard
from prettytable import PrettyTable 

class kothPlayerApi(kothScoreboard.kothScoreboard):
    """

    """
    _sUser = 'player'
    _sPass = None
    _sCrtFile = 'certs/cli.psql.scoreboard.player.crt'
    _sKeyFile = 'certs/cli.psql.scoreboard.player.key'

    def __init__(self):
        super().__init__()
    
    def getFormatCatProgressFromIp(self,playerIp):
        title = ['CatId','Category','DisplayName', 'Description','Score','Total'] 
        score = self.getCatProgressFromIp(playerIp)
        x = PrettyTable(title)
        x.align['Category'] = 'l'
        x.align['DisplayName'] = 'l'
        x.align['Description'] = 'l'
        x.padding_width = 1
        for row in score:
            x.add_row(row)
        return x

    def getFormatFlagProgressFromIp(self,playerIp):
        title = ['id','Name','Description','pts','CatId','CatName','isDone','Author','DisplayInterval'] 
        score = self.getFlagProgressFromIp(playerIp)
        x = PrettyTable(title)
        x.align['Name'] = 'l'
        x.align['Description'] = 'l'
        x.align['CatName'] = 'l'
        x.padding_width = 1
        for row in score:
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


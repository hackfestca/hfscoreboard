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

# Project imports
import config
from prettytable import PrettyTable 

# System imports
from xmlrpc.client import ServerProxy

class kothPlayer():
    """

    """
    _sHost = '192.168.1.100'
    _sPort = 8000
    _oRPC = None

    def __init__(self):
        self._oRPC = ServerProxy('http://%s:%i' % (self._sHost,self._sPort),allow_none=True)

    def submitFlag(self,flagValue):
        return self._oRPC.submitFlag(flagValue)

    def getScore(self,top=config.KOTH_DEFAULT_TOP_VALUE,ts=None,cat=None):
        return self._oRPC.getScore(top,ts,cat)

    def getCatProgress(self):
        return self._oRPC.getCatProgress()

    def getFlagProgress(self):
        return self._oRPC.getFlagProgress()

    def getNews(self):
        return self._oRPC.getNews()

    def getTeamInfo(self):
        return self._oRPC.getTeamInfo()


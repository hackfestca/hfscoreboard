#!/usr/bin/python
# -*- coding: utf-8 -*-

'''
Player controller class used by player.py

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
from xmlrpc.client import ServerProxy
from time import sleep
from datetime import datetime
import ssl

class PlayerController():
    """
    Player controller class used by player.py
    """
    _oRPC = None

    def __init__(self):
        # Setup SSL context
        if config.PLAYER_API_URI.startswith('https'):
            context = ssl.SSLContext(ssl.PROTOCOL_TLSv1_2)
            context.verify_mode = ssl.CERT_REQUIRED
            context.check_hostname = True
            #context.load_default_certs()       # To use installed CAs on the machine
            context.load_verify_locations(config.PLAYER_API_SSL_ROOT_CA)
        else:
            context = None
        self._oRPC = ServerProxy(config.PLAYER_API_URI,allow_none=True,use_builtin_types=True,context=context)

    def submitFlag(self,flagValue):
        return self._oRPC.submitFlag(flagValue)

    def getScore(self,top=config.DEFAULT_TOP_VALUE,ts=None,cat=None):
        return self._oRPC.getScore(top,ts,cat)

    def buyBMItem(self,bmItemId):
        return self._oRPC.buyBMItem(bmItemId)

    def sellBMItem(self,name,amount,qty,desc,data):
        return self._oRPC.sellBMItem(name,amount,qty,desc,data)

    def getBMItemInfo(self,bmItemId):
        return self._oRPC.getBMItemInfo(bmItemId)

    def getBMItemData(self,bmItemId):
        return self._oRPC.getBMItemData(bmItemId)

    def getBMItemList(self,top):
        return self._oRPC.getBMItemList(top)

    def getBMItemCategoryList(self):
        return self._oRPC.getBMItemCategoryList()

    def getBMItemStatusList(self):
        return self._oRPC.getBMItemStatusList()

    def buyLoto(self,amount):
        return self._oRPC.buyLoto(amount)

    def getLotoHistory(self,top):
        return self._oRPC.getLotoHistory(top)

    def getLotoInfo(self):
        return self._oRPC.getLotoInfo()

    def getCatProgress(self):
        return str(self._oRPC.getCatProgress())

    def getFlagProgress(self):
        return str(self._oRPC.getFlagProgress())

    def getNews(self):
        return self._oRPC.getNews()

    def getTeamInfo(self):
        return self._oRPC.getTeamInfo()

    def getTeamSecrets(self):
        return self._oRPC.getTeamSecrets()

    def getEvents(self,lastUpdate=None,facility=None,severity=None,grep=None,top=300):
        return self._oRPC.getEvents(lastUpdate,facility,severity,grep,top)

    def getLogEvents(self,lastUpdate=None,facility=None,severity=None,grep=None,top=300):
        return self._oRPC.getLogEvents(lastUpdate,facility,severity,grep,top)

    def printLiveEvents(self,lastUpdate=None,facility=None,severity=None,grep=None,top=300,refresh=10):
        events = self.getLogEvents(lastUpdate,facility,severity,grep,top)
        print(events)
        lastUpdate = datetime.now()
        sleep(refresh)

        while True:
            events = self.getLogEvents(lastUpdate,facility,severity,grep,top)
            if len(events) > 0:
                print(events)
                lastUpdate = datetime.now()
            sleep(refresh)


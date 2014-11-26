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
import socket
from xmlrpc.client import ServerProxy

class PlayerController():
    """
    Player controller class used by player.py
    """
    _oRPC = None

    def __init__(self):
        # Quick of host existence in DNS
        try:
            ip = socket.gethostbyname(config.PLAYER_API_HOST)
        except socket.gaierror as e:
            print('[-] Could not resolve %s' % (config.PLAYER_API_HOST))
            exit(1)

        self._oRPC = ServerProxy('http://%s:%i' % (config.PLAYER_API_HOST,config.PLAYER_API_PORT),allow_none=True)

    def submitFlag(self,flagValue):
        return self._oRPC.submitFlag(flagValue)

    def getScore(self,top=config.DEFAULT_TOP_VALUE,ts=None,cat=None):
        return self._oRPC.getScore(top,ts,cat)

    def getCatProgress(self):
        return str(self._oRPC.getCatProgress())

    def getFlagProgress(self):
        return str(self._oRPC.getFlagProgress())

    def getNews(self):
        return self._oRPC.getNews()

    def getTeamInfo(self):
        return self._oRPC.getTeamInfo()


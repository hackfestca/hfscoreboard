#!/usr/bin/python
# -*- coding: utf-8 -*-

'''
RPC Handler class used by player-api.py

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
import inspect
import psycopg2
from xmlrpc.server import SimpleXMLRPCRequestHandler,Fault
from lib import PlayerApiController
import re

def expose(*args, **kwargs):
    """ 
    A decorator to identify which methods are exposed (accessible from player.py)
    """
    def decorate(func):
        setattr(func, 'EXPOSE', True)
        return func

    if len(args):
        return decorate(args[0], **kwargs)
    else:
        return lambda func: decorate(func, **kwargs)

class RPCHandler(SimpleXMLRPCRequestHandler):
    '''
    RPC Handler class used by player-api.py
    '''
    _bDebug = False
    _oC = None
    behindProxy = False

    def _dispatch(self, method, params):
        # Find the method
        for name, func in inspect.getmembers(self):
           if name == method and \
              inspect.ismethod(func) and \
              getattr(func, 'EXPOSE', False):
                break

        # if a valid method is found, process.
        if func:
            if self.behindProxy:
                clientIP = self._getProxiedClientIp()
            else:
                clientIP = self.client_address[0]
            return func(clientIP, *params)

    def _dbConnect(self):
        try:
            self._oC = PlayerApiController.PlayerApiController()
            self._oC.setDebug(self._bDebug)
        except psycopg2.Error as e:
            submit_message = 'Error while connecting the database'
            print(e.pgerror)
            raise Fault(1, submit_message) 
            exit(1)
        except Exception as e:
            print(e)
            exit(1)

    def _dbClose(self):
        self._oC.close()

    def _dbExec(self,func,*args):
        try:
            ret = ''
            self._dbConnect()
            ret = getattr(self._oC,func)(*args)
            self._dbClose()
            return ret
        except psycopg2.InternalError as e: # All "raise" trigger this type of exception.
            print(e.diag.message_primary)   # Hopefully, it will not leak too much :/
            return e.diag.message_primary
        except psycopg2.IntegrityError as e:
            if e.diag.message_primary.startswith('duplicate key value violates unique constraint "u_flag_constraint"'):
                print('Flag already submitted.')
                return 'Flag already submitted.'
            elif e.diag.message_primary.startswith('duplicate key value violates unique constraint "bmitem_name_key"'):
                print('Item already submitted.')
                return 'Item already submitted.'
            else:
                return 'An error occured. Please contact an administrator.'
        except psycopg2.Error as e:
            print(type(e))
            print(e.pgerror)
            return 'An error occured. Please contact an administrator.'

    def _getProxiedClientIp(self):
        h = dict(re.findall(r"(?P<name>.*?): (?P<value>.*?)\n", str(self.headers)))
        if 'X-Real-IP' in h:
            return h['X-Real-IP']
        elif 'X-Forwarded-For' in h:
            return h['X-Forwarded-For']
        else:
            print('Error: Received a request without X-Real-IP or X-Forwarded-For headers')
            return None

    @expose()
    def submitFlag(self,clientIP,flagValue):
        return self._dbExec('submitFlagFromIp',flagValue,clientIP)

    @expose()
    def getScore(self,clientIP,top=config.DEFAULT_TOP_VALUE,ts=None,cat=None,ip=None):
        return self._dbExec('getFormatScore',top,ts,cat)

    @expose()
    def buyBMItem(self,clientIP,bmItemId):
        return self._dbExec('buyBMItemFromIp',int(bmItemId),clientIP)

    @expose()
    def sellBMItem(self,clientIP,name,amount,qty,desc,data):
        return self._dbExec('sellBMItemFromIp',name,amount,qty,desc,data,clientIP)

    @expose()
    def getBMItemInfo(self,clientIP,bmItemId):
        return self._dbExec('getFormatBMItemInfoFromIp',bmItemId,clientIP)

    @expose()
    def getBMItemLink(self,clientIP,bmItemId):
        return self._dbExec('getBMItemLinkFromIp',bmItemId,clientIP)

    @expose()
    def getBMItemData(self,clientIP,bmItemId):
        return self._dbExec('getBMItemDataFromIp',bmItemId,clientIP)

    @expose()
    def getBMItemList(self,clientIP,top):
        return self._dbExec('getFormatBMItemListFromIp',top,clientIP)

    @expose()
    def getBMItemCategoryList(self,clientIP):
        return self._dbExec('getFormatBMItemCategoryList')

    @expose()
    def getBMItemStatusList(self,clientIP):
        return self._dbExec('getFormatBMItemStatusList')

    @expose()
    def buyLoto(self,clientIP,amount):
        return self._dbExec('buyLotoFromIp',amount,clientIP)

    @expose()
    def getLotoHistory(self,clientIP,top):
        return self._dbExec('getFormatLotoHistory',top)

    @expose()
    def getLotoInfo(self,clientIP):
        return self._dbExec('getFormatLotoInfo')

    @expose()
    def getCatProgress(self,clientIP):
        return self._dbExec('getFormatCatProgressFromIp',clientIP)

    @expose()
    def getFlagProgress(self,clientIP):
        return self._dbExec('getFormatFlagProgressFromIp',clientIP)

    @expose()
    def getNews(self,clientIP):
        return self._dbExec('getFormatNews')

    @expose()
    def getTeamInfo(self,clientIP):
        return self._dbExec('getFormatTeamInfoFromIp',clientIP)

    @expose()
    def getTeamSecrets(self,clientIP):
        return self._dbExec('getFormatTeamSecretsFromIp',clientIP)

    @expose()
    def getEvents(self,clientIP,lastUpdate,facility,severity,grep,top):
        return self._dbExec('getFormatEventsFromIp',lastUpdate,facility,severity,grep,top,clientIP)

    @expose()
    def getLogEvents(self,clientIP,lastUpdate,facility,severity,grep,top):
        return self._dbExec('getLogEventsFromIp',lastUpdate,facility,severity,grep,top,clientIP)


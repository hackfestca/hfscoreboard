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
import postgresql.exceptions
from xmlrpc.server import SimpleXMLRPCRequestHandler,Fault
from lib import PlayerApiController

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

    def _dispatch(self, method, params):
        # Find the method
        for name, func in inspect.getmembers(self):
           if name == method and \
              inspect.ismethod(func) and \
              getattr(func, 'EXPOSE', False):
                break

        # if a valid method is found, process.
        if func:
            clientIP = self.client_address[0]
            for a in dir(self):
                print(a + ' ' + str(getattr(self,a)))
            print(dir(self))
            print(self.client_address)
            return func(clientIP, *params)

    def _dbConnect(self):
        try:
            self._oC = PlayerApiController.PlayerApiController()
            self._oC.setDebug(self._bDebug)
        except postgresql.exceptions.PLPGSQLRaiseError as e:
            print('[-] ('+str(e.code)+') '+e.message)
            raise Fault(e.code, e.message) 
            exit(1)
        except postgresql.exceptions.ClientCannotConnectError as e:
            print('[-] Insufficient privileges to connect to database')
            raise Fault(e.code, 'Insufficient privileges to connect to database') 
            exit(1);
        except postgresql.exceptions.InsecurityError as e:
            print('[-] Something insecure was detected. Please contact an admin')
            raise Fault(e.code, 'Something insecure was detected. Please contact an admin') 
            exit(1);
        except Exception as e:
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
        except postgresql.exceptions.PLPGSQLRaiseError as e:
            print('[-] ('+str(e.code)+') '+e.message)
            raise Fault(e.code, e.message) 
        except postgresql.exceptions.InsufficientPrivilegeError as e:
            print('[-] Insufficient privileges')
            raise Fault(e.code, 'Insufficient privileges') 
        except postgresql.exceptions.UniqueError as e:
            print('[-] Flag already submitted')
            raise Fault(e.code, 'Flag already submitted') 
        except postgresql.exceptions.StringRightTruncationError as e:
            print('[-] Input is too big ('+e.message+')')
            raise Fault(e.code, 'Input is too big') 
        except postgresql.exceptions.UndefinedFunctionError as e:
            print('[-] The specified function does not exist. Please contact an admin')
            raise Fault(e.code, 'The specified function does not exist. Please contact an admin') 
        except postgresql.message.Message as e:
            print(e)

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

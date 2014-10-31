#!/usr/bin/python
# -*- coding: utf-8 -*-

'''
King of the hill rpc class

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

import inspect
import config
import logging
import postgresql.exceptions

from xmlrpc.server import SimpleXMLRPCRequestHandler,Fault

from lib import kothPlayerApi

def expose(*args, **kwargs):
    """ 
    A decorator to identify which methods are exposed
    """
    def decorate(func):
        setattr(func, 'EXPOSE', True)
        return func

    if len(args):
        return decorate(args[0], **kwargs)
    else:
        return lambda func: decorate(func, **kwargs)

class rpcHandler(SimpleXMLRPCRequestHandler):
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
            return func(clientIP, *params)

    def _dbConnect(self):
        try:
            self._oC = kothPlayerApi.kothPlayerApi()
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
            print(e)
            exit(1)

    def _dbClose(self):
        self._oC.close()

    def _dbExec(self,func,*args):
        try:
            return str(func(*args))
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
        ret = ''
        self._dbConnect()
        ret = self._dbExec(self._oC.submitFlagFromIp,clientIP,flagValue)
        self._dbConnect()
        return ret

    @expose()
    def getScore(self,clientIP,top=config.KOTH_DEFAULT_TOP_VALUE,ts=None,cat=None,ip=None):
        ret = ''
        self._dbConnect()
        ret = self._dbExec(self._oC.getFormatScore,top,ts,cat)
        self._dbConnect()
        return ret

    @expose()
    def getCatProgress(self,clientIP):
        ret = ''
        self._dbConnect()
        ret = self._dbExec(self._oC.getFormatCatProgressFromIp,clientIP)
        self._dbConnect()
        return ret

    @expose()
    def getFlagProgress(self,clientIP):
        ret = ''
        self._dbConnect()
        ret = self._dbExec(self._oC.getFormatFlagProgressFromIp,clientIP)
        self._dbConnect()
        return ret

    @expose()
    def getNews(self,clientIP):
        ret = ''
        self._dbConnect()
        ret = self._dbExec(self._oC.getFormatNews)
        self._dbConnect()
        return ret

    @expose()
    def getTeamInfo(self,clientIP):
        ret = ''
        self._dbConnect()
        ret = self._dbExec(self._oC.getFormatTeamInfoFromIp,clientIP)
        self._dbConnect()
        return ret

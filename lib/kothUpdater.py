#!/usr/bin/python
# -*- coding: utf-8 -*-

'''
King of the Hill flag updater class

@author: Martin Dubé
@organization: Hackfest Communications
@license: GNU GENERAL PUBLIC LICENSE Version 3
@contact: martin.dube@hackfest.com

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

import time
import socket
import libssh2
import kothClient
from prettytable import PrettyTable 

class kothUpdater(kothClient.kothClient):
    """

    """
    _sVersion = '0.01'
    _sUser = 'flagupdater'
    _sPass = 'flagUpdater'

    STATUS_OK = 1
    STATUS_ERROR = 2
    STATUS_DISABLED = 3
    STATUS_MSG_ERROR = 'The flag was disabled because the service is not running properly'
    STATUS_MSG_DISABLED = 'The flag was disabled by admins'

    KING_FLAG_VALUE = 1

    def __init__(self):
        super().__init__()

    def _substituteCmd(self,cmd,flag):
        return cmd.replace('$FLAG', flag)
    
    def _getAllKingFlags(self):
        if self._bDebug:
            return list(self._benchmark(self._oDB.proc('getAllKingFlags()')))
        else:
            return list(self._oDB.proc('getAllKingFlags()')())

    def _getKingFlagsFromHost(self,host):
        if self._bDebug:
            return list(self._benchmark(self._oDB.proc('getKingFlagsFromHost(varchar)'),host))
        else:
            return list(self._oDB.proc('getKingableFlagsFromHost(varchar)')(host))

    def _getKingFlagFromName(self,name):
        if self._bDebug:
            return list(self._benchmark(self._oDB.proc('getKingFlagsFromName(varchar)'),name))
        else:
            return list(self._oDB.proc('getKingableFlagsFromName(varchar)')(name))

    def _addRandomFlagFromId(self,flagId):
        if self._bDebug:
            return self._benchmark(self._oDB.proc('addRandomKingFlagFromId(integer,integer)'),flagId,self.KING_FLAG_VALUE)
        else:
            return self._oDB.proc('addRandomKingFlagFromId()')(flagId,self.KING_FLAG_VALUE)
        
    
    def _remoteExec(self,host,cmd):
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.connect((host, 22))
        
        session = libssh2.Session()
        session.startup(sock)
        #session.userauth_password('john', '******')
        session.userauth_publickey_fromfile('root', \
                                            'certs/id_rsa.hf2014.pub',  
                                            'certs/id_rsa.hf2014', '')
        
        channel = session.channel()
        channel.execute(cmd)
        
        if self._bDebug:
            print('[+] Debug: SSH cmd output: '+str(channel.read(1024)))

        return 0

    def _updateFromList(self,flags):
        if len(list(flags)) != 0:

            for row in flags:
                flagId = row[0]
                flagName = row[1]
                host = row[2]
                updateCmd = row[3]
                statusCode = row[4]
                timestamp = str(time.strftime("%Y-%m-%d-%H%M"))
               
                # if statusCode is ok, generate and update the flag
                if statusCode == self.STATUS_OK:
                    flagValue = self._addRandomFlagFromId(flagId)
        
                    # Updating cmd and pushing the new flag
                    cmd = self._substituteCmd(updateCmd,flagValue)
                    self._remoteExec(host,cmd)
                    
                    if self._bDebug:
                        print('[+] %s Info: "%s" was updated on "%s" using "%s"' % (timestamp,flagName,host,cmd))
                    else:
                        print('[+] %s Info: "%s" was updated on "%s" using "%s"' % (timestamp,flagName,host,updateCmd))
                elif statusCode == self.STATUS_ERROR:
                    # Updating cmd and pushing the new error message
                    cmd = self._substituteCmd(updateCmd,self.STATUS_MSG_ERROR)
                    self._remoteExec(host,cmd)
                    print('[+] %s Info: "%s" was marked as erronous on "%s"' % (timestamp,flagName,host))
                elif statusCode == self.STATUS_DISABLED:
                    # Updating cmd and pushing the new error message
                    cmd = self._substituteCmd(updateCmd,self.STATUS_MSG_DISABLED)
                    self._remoteExec(host,cmd)
                    print('[+] %s Info: "%s" was marked as disabled on "%s"' % (timestamp,flagName,host))
            return 0
        else:
            print('[-] No flag were found with specified criteas')
            return 1

    def getFormatKingFlags(self):
        title = ['ID','Name','Host','UpdateCmd','Status','isKing']
        info = self._getAllKingFlags()
        x = PrettyTable(title)
        x.align['Info'] = 'l'
        x.align['Value'] = 'l'
        x.padding_width = 1
        for row in info:
            x.add_row(row)
        return x

    def updateAllFlags(self):
        return self._updateFromList(self._getAllKingFlags())

    def updateFlagsFromHost(self,host):
        return self._updateFromList(self._getKingFlagsFromHost(host))

    def updateFlagFromName(self,name):
        return self._updateFromList(self._getKingFlagFromName(name))

    

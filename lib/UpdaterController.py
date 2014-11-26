#!/usr/bin/python
# -*- coding: utf-8 -*-

'''
Flag updater controller class used by flagUpdater.py

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
import ClientController
import time
import socket
import libssh2
from prettytable import PrettyTable 

class UpdaterController(ClientController.ClientController):
    """
    Flag updater controller class used by flagUpdater.py
    """
    STATUS_OK = 1
    STATUS_ERROR = 2
    STATUS_DISABLED = 3
    STATUS_MSG_ERROR = 'The flag was disabled because the service is not running properly'
    STATUS_MSG_DISABLED = 'The flag was disabled by admins'

    KING_FLAG_VALUE = 2

    def __init__(self):
        self._sUser = config.DB_FU_USER
        self._sPass = config.DB_FU_PASS
        self._sCrtFile = config.DB_FU_CRT_FILE
        self._sKeyFile = config.DB_FU_KEY_FILE
        super().__init__()

    def _substituteCmd(self,cmd,flag):
        return cmd.replace('$FLAG', 'KOTH-'+flag)
    
    def _getAllKingFlags(self):
        if self._bDebug:
            return list(self._benchmark(self._oDB.proc('getAllKingFlags()')))
        else:
            return list(self._oDB.proc('getAllKingFlags()')())

    def _getKingFlagsFromHost(self,host):
        if self._bDebug:
            return list(self._benchmark(self._oDB.proc('getKingFlagsFromHost(varchar)'),host))
        else:
            return list(self._oDB.proc('getKingFlagsFromHost(varchar)')(host))

    def _getKingFlagFromName(self,name):
        if self._bDebug:
            return list(self._benchmark(self._oDB.proc('getKingFlagsFromName(varchar)'),name))
        else:
            return list(self._oDB.proc('getKingFlagsFromName(varchar)')(name))

    def _addRandomKingFlagFromId(self,flagId):
        if self._bDebug:
            return self._benchmark(self._oDB.proc('addRandomKingFlagFromId(integer,integer)'),flagId,self.KING_FLAG_VALUE)
        else:
            return self._oDB.proc('addRandomKingFlagFromId(integer,integer)')(flagId,self.KING_FLAG_VALUE)
        
    
    def _remoteExec(self,host,cmd):
        try:
            if self._bDebug:
                print('[+] Connecting to %s' % host)
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.connect((host, 22))
            
            session = libssh2.Session()
            session.startup(sock)
            #session.userauth_password('john', '******')

            session.userauth_publickey_fromfile(config.FLAG_UPDATER_SSH_USER, \
                                                config.FLAG_UPDATER_SSH_PUB_KEY, \
                                                config.FLAG_UPDATER_SSH_PRIV_KEY, \
                                                config.FLAG_UPDATER_SSH_PRIV_PWD)
            channel = session.channel()
            channel.execute(cmd)
            if self._bDebug:
                print('[+] Debug: SSH cmd output: '+str(channel.read(1024)))
        except socket.error as e:
            return (1,e)
        except libssh2.Error as e:
            return (1,e)

        return (0,None)

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
                    flagValue = self._addRandomKingFlagFromId(flagId)
        
                    # Updating cmd and pushing the new flag
                    cmd = self._substituteCmd(updateCmd,flagValue)
                    ret,msg = self._remoteExec(host,cmd)
                    
                    if ret == 0:
                        if self._bDebug:
                            print('[+] %s Info: "%s" was updated on "%s" using "%s"' % (timestamp,flagName,host,cmd))
                        else:
                            print('[+] %s Info: "%s" was updated on "%s" using "%s"' % (timestamp,flagName,host,updateCmd))
                    else:
                        print('[-] %s Error: Could not update on %s. (%s)' % (timestamp,host,msg))
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

    

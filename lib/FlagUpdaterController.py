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
import UpdaterController
import time
from prettytable import PrettyTable 

class FlagUpdaterController(UpdaterController.UpdaterController):
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

        self._sSSHUser = config.SSH_FU_USER
        self._sSSHPubKey = config.SSH_FU_PUB_KEY
        self._sSSHPrivKey= config.SSH_FU_PRIV_KEY
        self._sSSHPrivKeyPwd = config.SSH_FU_PRIV_PWD
        super().__init__()

    def _substituteCmd(self,cmd,flag):
        return cmd.replace('$FLAG', 'KOTH-'+flag)
    
    def _getAllKingFlags(self):
        return list(self.exec('getAllKingFlags'))

    def _getKingFlagsFromHost(self,host):
        return list(self.exec('getKingFlagsFromHost',host)

    def _getKingFlagFromName(self,name):
        return list(self.exec('getKingFlagsFromName',name)

    def _addRandomKingFlagFromId(self,flagId):
        return self.exec('addRandomKingFlagFromId',flagId,self.KING_FLAG_VALUE)
    
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

    

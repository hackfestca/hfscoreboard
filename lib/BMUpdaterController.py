#!/usr/bin/python
# -*- coding: utf-8 -*-

'''
Black market updater controller class used by bmUpdater.py

@author: Martin Dubé
@organization: Hackfest Communications
@license: Modified BSD License
@contact: martin.dube@hackfest.ca

Copyright (c) 2015, Hackfest Communications
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

class BMUpdaterController(ClientController.ClientController):
    """
    Black market updater controller class used by bmUpdater.py
    """

    STATUS_FOR_SALE = 1
    STATUS_SOLD = 2
    STATUS_FOR_APPROVAL= 3
    STATUS_REFUSED = 4
    STATUS_REMOVED = 5
    STATUS_TOPUBLISH = 6

    STATUS_MSG_ERROR = 'The flag was disabled because the service is not running properly'
    STATUS_MSG_DISABLED = 'The flag was disabled by admins'

    KING_FLAG_VALUE = 2
    STATUS_COL_ID = 3

    FE_ITEM_PATH = '/var/www/htdocs/blackmarket'

    def __init__(self):
        self._sUser = config.DB_FU_USER
        self._sPass = config.DB_FU_PASS
        self._sCrtFile = config.DB_FU_CRT_FILE
        self._sKeyFile = config.DB_FU_KEY_FILE
        super().__init__()

    def _substituteCmd(self,cmd,flag):
        return cmd.replace('$FLAG', 'KOTH-'+flag)
    
    def _getBMItems(self,top=30):
        if self._bDebug:
            return list(self._benchmark(self._oDB.proc('listBMItemsUpdater(integer)'),top))
        else:
            return list(self._oDB.proc('listBMItemsUpdater(integer)')(top))
        
    def _getBMItemsFromStatus(self,statusCode):
        return [x for x in self._getBMItems() if x[self.STATUS_COL_ID] == statusCode]
        
    def _getBMItemsDeleteAll(self):
        return [x[self.STATUS_COL_ID] = STATUS_REMOVED for x in self._getBMItems()]
        
    def _getBMItems(self,top=30):
        if self._bDebug:
            return list(self._benchmark(self._oDB.proc('listBMItemsUpdater(integer)'),top))
        else:
            return list(self._oDB.proc('listBMItemsUpdater(integer)')(top))
    
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

    def _updateFromList(self,bmItems):
        if len(list(bmItems)) != 0:

            for row in bmItems:
                bmItemId = row[0]
                bmItemName = row[1]
                bmItemCategory = row[2]
                bmItemStatus = row[3]
                bmItemStatusName = row[4]
                bmItemOwner = row[5]
                bmItemQty = row[6]
                bmItemPrivateId = row[7]
                bmItemDLLink= row[8]
                timestamp = str(time.strftime("%Y-%m-%d-%H%M"))
              
                # Remove items
                if bmItemStatusCode == STATUS_REMOVED or \
                    bmItemStatusCode == STATUS_SOLD:

                # Publish new items
                elif bmItemStatusCode == STATUS_TOPUBLISH:



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

    def getFormatBMItems(self):
        title = ['ID','Name','Category','Status','Rating','Owner','Cost','Qty']
        info = self._getBMItems()
        x = PrettyTable(title)
        x.align['Info'] = 'l'
        x.align['Value'] = 'l'
        x.padding_width = 1
        for row in info:
            x.add_row(row)
        return x

    def updateToPublish(self):
        return self._updateFromList(self._getBMItemsFromStatus(self.STATUS_TOPUBLISH))

    def updateSold(self,host):
        return self._updateFromList(self._getBMItemsFromStatus(self.STATUS_SOLD))

    def updateAll(self,name):
        return self._updateFromList(self._getBMItemsFromStatus())

    

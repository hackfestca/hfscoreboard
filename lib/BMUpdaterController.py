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
import UpdaterController
import time
import socket
import libssh2
from prettytable import PrettyTable 

class BMUpdaterController(UpdaterController.UpdaterController):
    """
    Black market updater controller class used by bmUpdater.py
    """

    BMI_STATUS_COL_ID = 3

    def __init__(self):
        self._sUser = config.DB_FU_USER
        self._sPass = config.DB_FU_PASS
        self._sCrtFile = config.DB_FU_CRT_FILE
        self._sKeyFile = config.DB_FU_KEY_FILE
        super().__init__()

    def _getBMItems(self,top=30):
        return list(self._exec('getBMItemListUpdater(integer)',top))
        
    def _getBMItemsFromStatus(self,statusCode):
        return [x for x in self._getBMItems() if x[self.BMI_STATUS_COL_ID] == statusCode]
        
    def _getBMItemsDeleteAll(self):
        return [x[self.BMI_STATUS_COL_ID] == config.BMI_STATUS_REMOVED for x in self._getBMItems()]

    def _addReviewReminder(self,bmiId):
        msg = 'The Black Market Item %s is waiting for a review'
        return self._exec('addEvent(text,varchar,varchar)',msg,'bm','warning')

    def _updateFromList(self,bmis):
        if len(list(bmis)) != 0:

            for row in bmis:
                bmiId = row[0]
                bmiName = row[1]
                bmiCategory = row[2]
                bmiStatusCode = row[3]
                bmiStatusName = row[4]
                bmiOwner = row[5]
                bmiQty = row[6]
                bmiPrivateId = row[7]
                bmiImportName = row[8]
                bmiUpdCmd = row[9]
                timestamp = str(time.strftime("%Y-%m-%d-%H%M"))
              
                # Remove items
                if bmiStatusCode == config.BMI_STATUS_REMOVED or \
                    bmiStatusCode == config.BMI_STATUS_SOLD:
                    self._removeBMItemFromScoreboard(bmiPrivateId)
                # Publish new items
                elif bmiStatusCode == config.BMI_STATUS_TO_PUBLISH:
                    self._uploadBMItemOnScoreboard(bmiImportName,privateId)
                    self._updateBMItemStatus(bmiId,config.BMI_STATUS_FOR_SALE)
                # Item is for sale
                elif bmiStatusCode == config.BMI_STATUS_FOR_SALE:
                    if bmiUpdCmd != None and bmiUpdCmd != '':
                        print('[+] Item can be updated. Updating.')
                        # Run the updateCmd
                        ret = self._localExec(bmiUpdCmd)

                        # Send on web servers
                        self._uploadBMItemOnScoreboard(bmImportName,privateId)
                # Send a reminder in the events
                elif bmiStatusCode == config.BMI_STATUS_FOR_APPROVAL:
                    self._addReviewReminder()
                # Refused items
                elif bmiStatusCode == config.BMI_STATUS_REFUSED:
                    pass
            return 0
        else:
            print('[-] No item was found with specified criteas')
            return 1

    def getFormatBMItems(self):
        title = ['ID','Name','Category','Status','Status Name','Owner','Qty','privateId','importName','updateCmd']
        info = self._getBMItems()
        x = PrettyTable(title)
        #x.align['Info'] = 'l'
        #x.align['Value'] = 'l'
        x.padding_width = 1
        for row in info:
            x.add_row(row)
        return x

    def updateToPublish(self):
        return self._updateFromList(self._getBMItemsFromStatus(config.BMI_STATUS_TO_PUBLISH))

    def updateSold(self,host):
        return self._updateFromList(self._getBMItemsFromStatus(config.BMI_STATUS_SOLD))

    def updateAll(self):
        return self._updateFromList(self._getBMItems())

    

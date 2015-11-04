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
import random

class LotoUpdaterController(UpdaterController.UpdaterController):
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

    def _getLotoCurrentList(self,top=30):
        return self.exec('getLotoCurrentList',top)
        
    def _processLotoWinner(self,walletId):
        return self.exec('processLotoWinner',walletId)

    def _uniq(self,seq):
        seen = set()
        seen_add = seen.add
        return [ x for x in seq if not (x in seen or seen_add(x))]

    def processWinner(self):
        # Get list of participants
        lotoCurrentList = self._getLotoCurrentList()
        participants = [x[0] for x in lotoCurrentList]
        participantsUniq = self._uniq(participants)
        participantsName = [x[1] for x in lotoCurrentList]
        participantsNameUniq = self._uniq(participantsName)

        # Determine a winner
        if len(participants) > 0:
            print('There are %s participants in the pool. %s are unique' % (len(participants),len(participantsUniq)))
            print('Unique participants are: %s' % ','.join(participantsNameUniq))

            winner = random.choice(participants)
            print('Winner is: %s' % winner)

            # Trigger stored proc
            return self._processLotoWinner(winner)
        else:
            print('No participants. Skipping.')
            exit(0)


    


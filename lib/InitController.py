#!/usr/bin/python
# -*- coding: utf-8 -*-

'''
Init controller class used by initDB.py.

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
import postgresql
import csv

class InitController(ClientController.ClientController):
    """
    Init controller class used by initDB.py.
    """

    def __init__(self):
        self._sUser = config.DB_INIT_USER
        self._sPass = config.DB_INIT_PASS
        self._sCrtFile = config.DB_INIT_CRT_FILE
        self._sKeyFile = config.DB_INIT_KEY_FILE
        self._flagsFile = config.FLAGS_FILE
        self._teamsFile = config.TEAMS_FILE
        super().__init__()
        
    def __del__(self):
        if self._oDB:
            self.close()
    
    def _sanitize(self,data,t):
        if type(data) == str and data.lower() == 'null':
            return None

        options = {'str' : str, \
                   'int': int, \
                   'bool': lambda x: True if type(x) == str and x.lower() == 'true' else False}
        return options[t](data)
                   
    def importTables(self):
        sql = ''.join(open(config.SQL_TABLE_FILE, 'r').readlines())
        self._oDB.execute(sql)

    def importFunctions(self):
        sql = ''.join(open(config.SQL_FUNC_FILE, 'r').readlines())
        self._oDB.execute(sql)

    def importData(self):
        sql = ''.join(open(config.SQL_DATA_FILE, 'r').readlines())
        self._oDB.execute(sql)

    def importFlags(self):
        with open(self._flagsFile) as csvfile:
            reader = csv.reader(csvfile, delimiter=',', quotechar='"')
            addFlag = self._oDB.proc('addFlag(varchar, \
                                    varchar, \
                                    integer, \
                                    varchar, \
                                    varchar, \
                                    integer, \
                                    varchar, \
                                    varchar, \
                                    varchar, \
                                    boolean, \
                                    text,    \
                                    text,    \
                                    varchar, \
                                    varchar)')
            addRandomFlag = self._oDB.proc('addRandomFlag(varchar, \
                                    integer, \
                                    varchar, \
                                    varchar, \
                                    integer, \
                                    varchar, \
                                    varchar, \
                                    varchar, \
                                    boolean, \
                                    text,    \
                                    text,    \
                                    varchar, \
                                    varchar)')
            with self._oDB.xact():
                for row in reader:
                    #print('|'.join(row))
                    fname = row[0]
                    fvalue = row[1]
                    fpts = row[2]
                    fhost = row[3]
                    fcat = row[4]
                    fstatus = 1
                    fdispint = row[5]
                    fauthor = row[6]
                    ftype = row[7]
                    fisking = row[8]
                    fdesc = row[9]
                    fhint = None
                    fupdcmd = row[10]
                    fmoncmd = None
                    
                    if fname != 'Flag Name':
                        if fvalue != '':
                            addFlag(self._sanitize(fname,'str'), \
                                    self._sanitize(fvalue,'str'), \
                                    self._sanitize(fpts,'int'), \
                                    self._sanitize(fhost,'str'), \
                                    self._sanitize(fcat,'str'), \
                                    self._sanitize(fstatus,'int'), \
                                    self._sanitize(fdispint,'str'), \
                                    self._sanitize(fauthor,'str'), \
                                    self._sanitize(ftype,'str'), \
                                    self._sanitize(fisking,'bool'), \
                                    self._sanitize(fdesc,'str'), \
                                    self._sanitize(fhint,'str'), \
                                    self._sanitize(fupdcmd,'str'), \
                                    self._sanitize(fmoncmd,'str'))
                        else:
                            addRandomFlag(self._sanitize(fname,'str'), \
                                    self._sanitize(fpts,'int'), \
                                    self._sanitize(fhost,'str'), \
                                    self._sanitize(fcat,'str'), \
                                    self._sanitize(fstatus,'int'), \
                                    self._sanitize(fdispint,'str'), \
                                    self._sanitize(fauthor,'str'), \
                                    self._sanitize(ftype,'str'), \
                                    self._sanitize(fisking,'bool'), \
                                    self._sanitize(fdesc,'str'), \
                                    self._sanitize(fhint,'str'), \
                                    self._sanitize(fupdcmd,'str'), \
                                    self._sanitize(fmoncmd,'str'))

    def importTeams(self):
        with open(self._teamsFile) as csvfile:
            reader = csv.reader(csvfile, delimiter=',', quotechar='"')
            addTeam = self._oDB.proc('addTeam(varchar,varchar)')
            with self._oDB.xact():
                for row in reader:
                    #print('|'.join(row))
                    tname = row[0]
                    tnet = row[1]
                    
                    if tname != 'Team Name':
                        addTeam(self._sanitize(tname,'str'), \
                                self._sanitize(tnet,'str'))

    def importSecurity(self):
        sql = ''.join(open(config.SQL_SEC_FILE, 'r').readlines())
        self._oDB.execute(sql)

    def importAll(self):
        self.importTables()
        self.importFunctions()
        self.importData()
        self.importFlags()
        self.importTeams()
        self.importSecurity()


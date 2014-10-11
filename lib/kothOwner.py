#!/usr/bin/python
# -*- coding: utf-8 -*-

'''
King of the hill client class

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

import config
import kothClient
import postgresql
import csv

class kothOwner(kothClient.kothClient):
    """

    """
    _sUser = 'hfowner'
    _sPass = None
    _sCrtFile = 'certs/cli.psql.scoreboard.hfowner.crt'
    _sKeyFile = 'certs/cli.psql.scoreboard.hfowner.key'
    _sSqlFolder = 'sql'
    _flagsFile = 'flags.csv'

    def __init__(self):
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
        sql = ''.join(open(self._sSqlFolder+'/koth-tables.sql', 'r').readlines())
        self._oDB.execute(sql)

    def importFunctions(self):
        sql = ''.join(open(self._sSqlFolder+'/koth-func.sql', 'r').readlines())
        self._oDB.execute(sql)

    def importData(self):
        sql = ''.join(open(self._sSqlFolder+'/koth-data.sql', 'r').readlines())
        self._oDB.execute(sql)


#CREATE OR REPLACE FUNCTION addFlag(_name flag.name%TYPE, 
#                                    _value flag.value%TYPE, 
#                                    _pts flag.pts%TYPE,
#                                    _host host.name%TYPE,
#                                    _category category.name%TYPE,
#                                    _statusCode status.code%TYPE default 1,
#                                    _displayInterval varchar(20) default Null,
#                                    _author flagAuthor.name%TYPE  default Null,
#                                    _isKing flag.isKing%TYPE default false,
#                                    _description flag.description%TYPE default '',
#                                    _hint flag.hint%TYPE default '',
#                                    _updateCmd flag.updateCmd%TYPE default '',
#                                    _monitorCmd flag.monitorCmd%TYPE default ''
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
                                    boolean, \
                                    text,    \
                                    text,    \
                                    varchar, \
                                    varchar)')
            with self._oDB.xact():
                for row in reader:
                    print('|'.join(row))
                    fname = row[0]
                    fvalue = row[1]
                    fpts = row[2]
                    fhost = row[3]
                    fcat = row[4]
                    fstatus = 1
                    fdispint = row[5]
                    fauthor = row[6]
                    fisking = row[7]
                    fdesc = row[8]
                    fhint = None
                    fupdcmd = row[9]
                    fmoncmd = None
                    
                    if fname != 'Flag Name':
                        addFlag(self._sanitize(fname,'str'), \
                                self._sanitize(fvalue,'str'), \
                                self._sanitize(fpts,'int'), \
                                self._sanitize(fhost,'str'), \
                                self._sanitize(fcat,'str'), \
                                self._sanitize(fstatus,'int'), \
                                self._sanitize(fdispint,'str'), \
                                self._sanitize(fauthor,'str'), \
                                self._sanitize(fisking,'bool'), \
                                self._sanitize(fdesc,'str'), \
                                self._sanitize(fhint,'str'), \
                                self._sanitize(fupdcmd,'str'), \
                                self._sanitize(fmoncmd,'str'))

    def importSecurity(self):
        sql = ''.join(open(self._sSqlFolder+'/koth-sec.sql', 'r').readlines())
        self._oDB.execute(sql)

    def importAll(self):
        self.importTables()
        self.importFunctions()
        self.importData()
        self.importFlags()
        self.importSecurity()


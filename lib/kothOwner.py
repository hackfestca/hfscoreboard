#!/usr/bin/python
# -*- coding: utf-8 -*-

'''
King of the hill client class

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

import config
import kothClient
import postgresql

class kothOwner(kothClient.kothClient):
    """

    """
    _sUser = 'hfowner'
    _sHost = 'mon2k14.hf'
    _sPass = ''
    _sCrtFile = 'certs/cli.psql.mon2k14.crt'
    _sKeyFile = 'certs/cli.psql.mon2k14.key'
    _sSqlFolder = 'sql'


    def __init__(self):
        self._oDB = postgresql.open( \
                    user = self._sUser, \
                    host = self._sHost, \
                    database = self._sDatabase, \
                    connect_timeout = self._iTimeout, \
                    sslmode = 'require', \
                    sslcrtfile = self._sCrtFile, \
                    sslkeyfile = self._sKeyFile, \
                    sslrootcrtfile = self._sslRootCrt)
        self._oDB.settings['search_path'] = self._sSchema
        
    def __del__(self):
        if self._oDB:
            self.close()

    def importTables(self):
        sql = ''.join(open(self._sSqlFolder+'/koth-tables.sql', 'r').readlines())
        self._oDB.execute(sql)

    def importFunctions(self):
        sql = ''.join(open(self._sSqlFolder+'/koth-func.sql', 'r').readlines())
        self._oDB.execute(sql)

    def importData(self):
        sql = ''.join(open(self._sSqlFolder+'/koth-data.sql', 'r').readlines())
        self._oDB.execute(sql)

    def importSecurity(self):
        sql = ''.join(open(self._sSqlFolder+'/koth-sec.sql', 'r').readlines())
        self._oDB.execute(sql)

    def importAll(self):
        self.importTables()
        self.importFunctions()
        self.importData()
        self.importSecurity()


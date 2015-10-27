#!/usr/bin/python
# -*- coding: utf-8 -*-

'''
Scripts config file

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

DEFAULT_TOP_VALUE = 300

PLAYER_API_LISTEN_ADDR = '127.0.0.1'
PLAYER_API_LISTEN_PORT = 8000
PLAYER_API_URI = 'https://scoreboard.hf'
#PLAYER_API_URI = 'http://127.0.0.1:8000'
PLAYER_API_URI_OLD = 'http://scoreboard.hf'   # python < 3.4.0
PLAYER_API_SSL_ROOT_CA = 'certs/hf.ca.ctf.chain.crt'

DB_HOST = 'db.hf'
DB_SCHEMA = 'scoreboard'
DB_NAME = 'scoreboard'
DB_SSL_ROOT_CA = 'certs/hf.ca.sb.chain.crt'
DB_CONNECT_TIMEOUT = 2

DB_INIT_USER = 'owner'
DB_INIT_PASS = None
DB_INIT_CRT_FILE = 'certs/hf.cli.db.owner.crt'
DB_INIT_KEY_FILE = 'certs/hf.cli.db.owner.key'

DB_ADMIN_USER = 'admin'
DB_ADMIN_PASS = 'zWMmhIpSQlcFlNOu8rfpr'
DB_ADMIN_CRT_FILE = None
DB_ADMIN_KEY_FILE = None

DB_WEB_USER = 'web'
DB_WEB_PASS = None
DB_WEB_CRT_FILE = 'certs/hf.cli.db.web.crt'
DB_WEB_KEY_FILE = 'certs/hf.cli.db.web.key'

DB_PLAYER_USER = 'player'
DB_PLAYER_PASS = None
DB_PLAYER_CRT_FILE = 'certs/hf.cli.db.player.crt'
DB_PLAYER_KEY_FILE = 'certs/hf.cli.db.player.key'

DB_FU_USER = 'flagupdater'
DB_FU_PASS = None
DB_FU_CRT_FILE = 'certs/hf.cli.db.flagupdater.crt'
DB_FU_KEY_FILE = 'certs/hf.cli.db.flagupdater.key'

DB_BMU_USER = 'flagupdater'
DB_BMU_PASS = None
DB_BMU_CRT_FILE = 'certs/hf.cli.db.flagupdater.crt'
DB_BMU_KEY_FILE = 'certs/hf.cli.db.flagupdater.key'

SQL_DATA_FILE = 'sql/data.sql'
SQL_FUNC_FILE = 'sql/functions.sql'
SQL_TABLE_FILE = 'sql/tables.sql'
SQL_SEC_FILE = 'sql/security.sql'

SSH_FU_USER = 'root'
SSH_FU_PUB_KEY = 'certs/id_rsa.hf2015.pub'
SSH_FU_PRIV_KEY = 'certs/id_rsa.hf2015'
SSH_FU_PRIV_PWD = ''

SSH_BMU_USER = 'scoreboard'
SSH_BMU_PUB_KEY = 'certs/id_rsa.hf2015.pub'
SSH_BMU_PRIV_KEY = 'certs/id_rsa.hf2015'
SSH_BMU_PRIV_PWD = ''

BMI_HOSTS = ['scoreboard.hf']
BMI_LOCAL_PATH = './blackmarket'
BMI_REMOTE_PATH = '/var/www/htdocs/blackmarket'

BMI_STATUS_FOR_SALE = 1
BMI_STATUS_SOLD = 2
BMI_STATUS_FOR_APPROVAL= 3
BMI_STATUS_REFUSED = 4
BMI_STATUS_REMOVED = 5
BMI_STATUS_TO_PUBLISH = 6
BMI_STATUS_TO_RETRIEVE = 7

COMPETITION_MODE = True
'''
Not implemented yet. Enable to ensure nobody can accidentally delete data with initDB.py during competition.
@type: bool
'''

BENCH_DEFAULT_REQ_NUM = 50
BENCH_DEFAULT_CON_NUM = 30

FLAGS_FILE = 'import/flags.csv'
TEAMS_FILE = 'import/teams.csv'
BMI_FILE = 'import/blackMarketItems.csv'


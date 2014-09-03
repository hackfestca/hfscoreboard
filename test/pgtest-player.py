#!/usr/bin/python3.2
import postgresql
import time


t0 = time.time()
db = postgresql.open( \
        user = 'player', \
        password = 'player', \
        host = 'mon2k14.hf', \
        database = 'mon2k14', \
        connect_timeout = 2, \
        sslmode = 'require')
#db.settings['search_path'] = "mon2k14"

print('a')
addTeam = db.proc('addTeam(varchar,varchar)')
print('b')
#addTeam('Team Dube', '192.168.1.0/24')


# Error management
#try:
#    with db.xact():
#        pass
#except postgresql.exceptions.UniqueError:
#    pass



db.close()



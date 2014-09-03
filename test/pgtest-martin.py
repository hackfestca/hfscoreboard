#!/usr/bin/python3.2
import postgresql
import time

t0 = time.time()
db = postgresql.open( \
        user = 'martin', \
        password = 'h9N)kv1*H!3(|<eASR1^]Iwql;fsDIDc6h.?o\,IS[v?4:~}J0', \
        host = 'mon2k14.hf', \
        database = 'mon2k14', \
        connect_timeout = 2, \
        sslmode = 'require')
db.settings['search_path'] = "mon2k14"
t1 = time.time()

#db.execute('select * from status;')

#sql = ''.join(open('cnc.sql', 'r').readlines())
#db.execute(sql)

getScore = db.proc('getScore(integer)')
t2 = time.time()
res = getScore(None)
t3 = time.time()
print(list(res))
t4 = time.time()

print('db.open = '+str(t1 - t0))
print('db.proc = '+str(t2 - t1))
print('getScore = '+str(t3 - t2))
print('print = '+str(t4 - t3))

# Error management
#try:
#    with db.xact():
#        pass
#except postgresql.exceptions.UniqueError:
#    pass



db.close()


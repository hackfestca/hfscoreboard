#!/usr/bin/python3
# -*- coding: utf-8 -*-

# Python version validation
import sys
if sys.version_info < (3,2,0):
    print('Python version 3.2 or later is needed for this script')
    exit(1);

# Should be used only for admin side
sys.path.insert(0, 'lib')
del sys

# Project imports
import config
from lib.kothScoreboard import kothScoreboard

import tornado.web
import tornado.ioloop
import tornado.httpserver

# System imports
import os
import postgresql.exceptions

class BaseHandler(tornado.web.RequestHandler):

    def __init__(self, *args):
        super().__init__(*args)
        _sponsors_imgs_path = os.path.join(os.path.dirname(__file__), "static/sponsors")
        self._sponsors = [ "/static/sponsors/" + f for f in os.listdir(_sponsors_imgs_path) \
                if os.path.isfile(os.path.join(_sponsors_imgs_path, f)) ]
        self.client = None

                
    def prepare(self):
        try:
            self.client = kothScoreboard()
        except Exception as e:
            self.render('templates/error.html', error_msg=e.message)
            
    def on_finish(self):
        self.client.close()
                
    @property
    def sponsors(self):
        return self._sponsors
    
                
class ScoreHandler(BaseHandler):
    def get(self):
        client = kothScoreboard()
        score = client.getScore()
        client.close()
        self.render('templates/score.html',
                           table=score
                       )

class ChallengesHandler(BaseHandler):
    def get(self):
        categories = self.client.getCatProgressFromIp("192.168.9.22")
        challenges = self.client.getFlagProgressFromIp("192.168.9.22")
        self.render('templates/challenges.html', cat=list(categories), chal=list(challenges))

class IndexHandler(BaseHandler):
    def get(self):
        score = self.client.getScore(top=9)
        valid_news = self.client.getValidNews()

        self.render('templates/index.html', table=score, news=valid_news, sponsors=self.sponsors)

    def post(self):
        flag = self.get_argument("flag")
        score = self.client.getScore(top=9)
        valid_news = self.client.getValidNews()

        try:
            client.submitFlagFromIp("192.168.9.22", flag)
        except postgresql.exceptions.UniqueError:
            submit_message = "Flag already submitted"
            flag_is_valid = False
        except postgresql.exceptions.PLPGSQLRaiseError as e:
            submit_message = e.message
            flag_is_valid = False
        except Exception:
            submit_message = "Error"
            flag_is_valid = False
        else:
            submit_message = "Flag successfully submitted"
            flag_is_valid = True
            
        self.render('templates/index.html', table=score, news=valid_news, sponsors=self.sponsors, \
                    flag_is_valid=flag_is_valid, submit_message=submit_message)        

class DashboardHandler(BaseHandler):
    def get(self):
        jsArray = self.client.getJsDataScoreProgress()
        self.render('templates/dashboard.html', sponsors=self.sponsors, jsArray=jsArray)

if __name__ == '__main__':
    # For the CSS
    root = os.path.dirname(__file__)

    app = tornado.web.Application([
            (r"/", IndexHandler),
            (r"/challenges/?", ChallengesHandler),
            (r"/scoreboard/?", ScoreHandler),
            (r"/dashboard/?", DashboardHandler)
        ], debug=True, static_path=os.path.join(root, 'static'))

    server = tornado.httpserver.HTTPServer(app,
                        ssl_options = {
                            "certfile": "./certs/scoreboard-web.crt",
                            "keyfile": "./certs/scoreboard-web-key.pem",
                            }
                    )
        
    server.listen(5000)
    tornado.ioloop.IOLoop.instance().start()

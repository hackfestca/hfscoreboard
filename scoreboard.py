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
import logging
from postgresql.exceptions import *

class Logger(logging.getLoggerClass()):

    def __init__(self, name):
        super().__init__(name)
        self.logger = logging.getLogger("scoreboard_logger")
        self.logger.setLevel(logging.ERROR)

        error_file = logging.FileHandler("logs/errors.log", encoding="utf-8", )
        error_file.setLevel(logging.ERROR)
        error_formatter = logging.Formatter('%(asctime)s:l.%(lineno)s - %(message)s')
        error_file.setFormatter(error_formatter)

        info_file = logging.FileHandler("logs/infos.log", encoding="utf-8", )
        info_file.setLevel(logging.INFO)
        info_formatter = logging.Formatter('%(asctime)s:l.%(lineno)s - %(message)s')
        info_file.setFormatter(info_formatter)        

        self.logger.addHandler(error_file)
        self.logger.addHandler(info_file)

    def error(self, msg):
        self.logger.error(msg)
        
    def info(self, msg):
        self.logger.info(msg)
    
class BaseHandler(tornado.web.RequestHandler):

    def __init__(self, *args):
        super().__init__(*args)
        _sponsors_imgs_path = os.path.join(os.path.dirname(__file__), "static/sponsors")
        self._sponsors = [ "/static/sponsors/" + f for f in os.listdir(_sponsors_imgs_path) \
                if os.path.isfile(os.path.join(_sponsors_imgs_path, f)) ]
        self.client = None
        self.logger = Logger("HF2k14_Logger")

                
    def prepare(self):
        try:
            self.client = kothScoreboard()
        except ClientCannotConnectError as e:
            self.logger.error(e.message)
            self.render('templates/error.html', error_msg=e.message)
        except Exception as e:
            self.logger.error(e)
            self.render('templates/error.html', error_msg=e)
            
    def on_finish(self):
        try:
            self.client.close()
        except (AttributeError, Exception, RuntimeError) as e:
            self.logger.error(e)

    @property
    def sponsors(self):
        return self._sponsors
    
                
class ScoreHandler(BaseHandler):
    def get(self):
        try:
            score = self.client.getScore()
        except PLPGSQLRaiseError as e:
            self.logger.error(e.message)
            self.render('templates/error.html', error_msg=e.message)
        except Exception as e:
            self.logger.error(e)
            self.render('templates/error.html', error_msg="Error")
            
        self.render('templates/score.html',
                           table=score
                       )

class ChallengesHandler(BaseHandler):
    def get(self):
        try:
            categories = self.client.getCatProgressFromIp("192.168.9.22")
            challenges = self.client.getFlagProgressFromIp("192.168.9.22")
        except PLPGSQLRaiseError as e:
            self.logger.error(e.message)
            self.render('templates/error.html', error_msg="Error")
        except Exception as e:
            self.logger.error(e)
            
        self.render('templates/challenges.html', cat=list(categories), chal=list(challenges))

class IndexHandler(BaseHandler):
    def get(self):
        try:
            score = self.client.getScore(top=9)
            valid_news = self.client.getValidNews()
        except PLPGSQLRaiseError as e:
            self.logger.error(e.message)
            self.render('templates/error.html', error_msg=e.message)
        except Exception as e: 
            self.logger.error(e)


        self.render('templates/index.html', table=score, news=valid_news, sponsors=self.sponsors)

    def post(self):
        flag = self.get_argument("flag")
        score = self.client.getScore(top=9)
        valid_news = self.client.getValidNews()

        try:
            client.submitFlagFromIp("192.168.9.22", flag)
        except UniqueError:
            submit_message = "Flag already submitted"
            flag_is_valid = False
        except PLPGSQLRaiseError as e:
            submit_message = e.message
            flag_is_valid = False
        except Exception as e:
            self.logger.error(e)
            submit_message = "Error"
            flag_is_valid = False
        else:
            submit_message = "Flag successfully submitted"
            flag_is_valid = True
            
        self.render('templates/index.html', table=score, news=valid_news, sponsors=self.sponsors, \
                    flag_is_valid=flag_is_valid, submit_message=submit_message)        

class DashboardHandler(BaseHandler):
    def get(self):
        try:
            jsArray = self.client.getJsDataScoreProgress()
        except PLPGSQLRaiseError as e:
            self.logger.error(e.message)
            self.render('templates/error.html', error_msg=e.message)
        except Exception as e:
            self.logger.error(e)
            self.render('templates/error.html', error_msg="Error")
            
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

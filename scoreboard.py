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
        self._client = None
        self._logger = Logger("HF2k14_Logger")
        self._team_name = None
        self._team_ip = None
        self._team_score = None

    def _connect(self):
        try:
            self.client = kothScoreboard()
        except ClientCannotConnectError as e:
            self.logger.error(e.message)
            self.render('templates/error.html', error_msg=e.message)
        except Exception as e:
            self.logger.error(e)
            self.render('templates/error.html', error_msg=e)

    def _getTeamInfo(self):
        try:
            team_info = list(self.client.getTeamInfo(self.request.remote_ip))
            self.team_name = team_info[1][1]
            self.team_ip = team_info[2][1]
            self.team_score = team_info[6][1]
        except PLPGSQLRaiseError as e:
            self.logger.error(e.message)
            self.render('templates/error.html', error_msg=e)
        except Exception as e:
            self.logger.error(e.message)
            self.render('templates/error.html', error_msg=e)

    def _disconnect(self):
        try:
            self.client.close()
        except (AttributeError, Exception, RuntimeError) as e:
            self.logger.error(e)

    def prepare(self):
        self._connect()
        self._getTeamInfo()
        
                            
    def on_finish(self):
        self._disconnect()

    def render(self, template_name, **kwargs):
        super().render(template_name,
                        team_name=self.team_name,
                        team_ip=self.team_ip,
                        team_score=self.team_score,
                        **kwargs)

    @property
    def sponsors(self):
        return self._sponsors

    @property
    def client(self):
        return self._client

    @client.setter
    def client(self, arg):
        self._client = arg

    @property
    def logger(self):
        return self._logger

    @logger.setter
    def logger(self, arg):
        self._logger = arg
        
    @property
    def team_name(self):
        return self._team_name

    @team_name.setter
    def team_name(self, arg):
        self._team_name = arg

    @property
    def team_ip(self):
        return self._team_ip

    @team_ip.setter
    def team_ip(self, arg):
        self._team_ip = arg

    @property
    def team_score(self):
        return self._team_score

    @team_score.setter
    def team_score(self, arg):
        self._team_score = arg
        
class ScoreHandler(BaseHandler):
    @tornado.web.addslash
    def get(self):
        try:
            score = self.client.getScore()
        except PLPGSQLRaiseError as e:
            self.set_status(500)
            self.logger.error(e.message)
            self.render('templates/error.html', error_msg=e.message)
        except Exception as e:
            self.set_status(500)
            self.logger.error(e)
            self.render('templates/error.html', error_msg="Error")

        # Weird behaviour from PGSQL
        try:
            self.render('templates/score.html', score_table=score)
        except PLPGSQLRaiseError as e:
            self.logger.error(e)
            self.set_status(500)
            self.render('templates/error.html', error_msg=e.message)
            
class ChallengesHandler(BaseHandler):
    @tornado.web.addslash
    def get(self):
        try:
            categories = self.client.getCatProgressFromIp(self.request.remote_ip)
            challenges = self.client.getFlagProgressFromIp(self.request.remote_ip)
        except PLPGSQLRaiseError as e:
            self.logger.error(e.message)
            self.set_status(500)
            self.render('templates/error.html', error_msg=e.message)
        except Exception as e:
            self.set_status(500)
            self.logger.error(e)
            self.render('templates/error.html', error_msg="Error")
        else:    
            self.render('templates/challenges.html', cat=list(categories), chal=list(challenges))

class IndexHandler(BaseHandler):
    @tornado.web.addslash
    def get(self):
        try:
            score = self.client.getScore(top=9)
            valid_news = self.client.getValidNews()
        except PLPGSQLRaiseError as e:
            self.logger.error(e.message)
            self.set_status(500)
            self.render('templates/error.html', error_msg=e.message)
        except Exception as e:
            self.set_status(500)
            self.logger.error(e)
            self.render('templates/error.html', error_msg="Error")

        # This weird thing again
        try:
            self.render('templates/index.html', table=score, news=valid_news, sponsors=self.sponsors)
        except PLPGSQLRaiseError as e:
            self.logger.error(e.message)
            self.set_status(500)
            self.render('templates/error.html', error_msg=e.message)
            
    def post(self):
        flag = self.get_argument("flag")
        score = self.client.getScore(top=9)
        valid_news = self.client.getValidNews()

        try:
            self.client.submitFlagFromIp(self.request.remote_ip, flag)
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
            self.set_status(500)
        else:
            submit_message = "Flag successfully submitted"
            flag_is_valid = True
            
        self.render('templates/index.html', table=score, news=valid_news, sponsors=self.sponsors, \
                    flag_is_valid=flag_is_valid, submit_message=submit_message)

class DashboardHandler(BaseHandler):
    @tornado.web.addslash
    def get(self):
        try:
            jsArray = self.client.getJsDataScoreProgress()
        except PLPGSQLRaiseError as e:
            self.logger.error(e.message)
            self.set_status(500)
            self.render('templates/error.html', error_msg=e.message)
        except Exception as e:
            self.set_status(500)
            self.logger.error(e)
            self.render('templates/error.html', error_msg="Error")

        try:
            self.render('templates/dashboard.html', sponsors=self.sponsors, jsArray=jsArray)
        except PLPGSQLRaiseError as e:
            self.logger.error(e.message)
            self.set_status(500)
            self.render('templates/error.html', error_msg=e.message)
            
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

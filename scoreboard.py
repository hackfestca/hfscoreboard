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
        error_formatter = logging.Formatter('%(asctime)s - %(message)s')
        error_file.setFormatter(error_formatter)

        info_file = logging.FileHandler("logs/infos.log", encoding="utf-8", )
        info_file.setLevel(logging.INFO)
        info_formatter = logging.Formatter('%(asctime)s - %(message)s')
        info_file.setFormatter(info_formatter)        

        self.logger.addHandler(error_file)
        self.logger.addHandler(info_file)

    def error(self, msg):
        self.logger.error(msg)
        
    def info(self, msg):
        self.logger.info(msg)
    
class BaseHandler(tornado.web.RequestHandler):

    def initialize(self, sponsors_imgs):
#        super().__init__(*args)
        self._client = None
        self._logger = Logger("HF2k14_Logger")
        self._team_name = None
        self._team_ip = None
        self._team_score = None
        self._sponsors = sponsors_imgs

    def write_error(self, status_code, **kwargs):
        # Handler for all the internals Error (500)
        # Handle every exception thrown by any BaseHadler
        import traceback

        exc_type, exc_obj, exc_tb = kwargs["exc_info"]

        if issubclass(exc_type, ConnectionError):
            msg = "{} - {}".format(status_code, exc_obj.message)
        elif isinstance(exc_type, PLPGSQLRaiseError):
            msg = "{} - {}".format(status_code, exc_obj.message)
        elif isinstance(exc_type, InsufficientPrivilegeError):
            msg = "{} - {}".format(status_code, exc_obj.message)
        else:
            msg = status_code

        self.logger.error("{}:{}:{}".format(self.request.remote_ip,
                                            exc_type.__name__,
                                            exc_obj.message))
        self.render("templates/error.html", error_msg=msg)
        
    def _connect(self):
        self.client = kothScoreboard()

    def _getTeamInfo(self):
        try:
            team_info = list(self.client.getTeamInfo(self.request.remote_ip))
            self.team_name = team_info[1][1]
            self.team_ip = team_info[2][1]
            self.team_score = team_info[6][1]
        except Exception as e:
            self.logger.error(e)
            self.render('templates/error.html', error_msg=e)

    def _disconnect(self):
        try:
            self.client.close()
        except AttributeError:
            pass # The connection was never established
            
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
            score = self.client.getScore(top=200)
        except Exception as e:
            self.set_status(500)
            self.logger.error(e)
            self.render('templates/error.html', error_msg="Error")
        else:
            self.render('templates/score.html', score_table = score)

            
class ChallengesHandler(BaseHandler):
    @tornado.web.addslash
    def get(self):
        try:
            categories = self.client.getCatProgressFromIp(self.request.remote_ip)
            challenges = self.client.getFlagProgressFromIp(self.request.remote_ip)
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
        except Exception as e:
            self.set_status(500)
            self.logger.error(e)
            self.render('templates/error.html', error_msg="Error")
        else:
            self.render('templates/index.html', table=score, news=valid_news, sponsors=self.sponsors)
            
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
        except Exception as e:
            self.set_status(500)
            self.logger.error(e)
            self.render('templates/error.html', error_msg="Error")
        else:
            self.render('templates/dashboard.html', sponsors=self.sponsors, jsArray=jsArray)


class Error404Handler(BaseHandler):

    def initialize(self):
        self._client = None
        self._logger = Logger("HF2k14_Logger")
        self._team_name = None
        self._team_ip = None
        self._team_score = None
    
    def get(self):
        self.set_status(404)
        self.render('templates/error.html', error_msg="404 - Not Found")
                        
if __name__ == '__main__':
    # For the CSS
    root = os.path.dirname(__file__)

    sponsors_imgs_path = os.path.join(os.path.dirname(__file__), "static/sponsors")
    sponsors_imgs = [ "/static/sponsors/" + f for f in os.listdir(sponsors_imgs_path) \
                        if os.path.isfile(os.path.join(sponsors_imgs_path, f)) ]
    
    app = tornado.web.Application([
            (r"/", IndexHandler, dict(sponsors_imgs=sponsors_imgs)),
            (r"/challenges/?", ChallengesHandler, dict(sponsors_imgs=sponsors_imgs)),
            (r"/scoreboard/?", ScoreHandler, dict(sponsors_imgs=sponsors_imgs)),
            (r"/dashboard/?", DashboardHandler, dict(sponsors_imgs=sponsors_imgs))
        ],
         debug=True,
         static_path=os.path.join(root, 'static'),
         default_handler_class=Error404Handler # 404 Handling
         )

    server = tornado.httpserver.HTTPServer(app#,
#                        ssl_options = {
#                            "certfile": "./certs/scoreboard-web.crt",
#                            "keyfile": "./certs/scoreboard-web-key.pem",
#                            }
                    )
        
    server.listen(5000)
    tornado.ioloop.IOLoop.instance().start()

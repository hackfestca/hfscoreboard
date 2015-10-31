#!/usr/bin/env python3
# -*- coding: utf-8 -*-

'''
This script is the main interface for players to submit flags and display score

@author: _eko
@organization: Hackfest Communications
@license: Modified BSD License
@contact: mail.jessy.campos@gmail.com

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

# Python version validation
import sys
if sys.version_info < (3, 2, 0):
    print('Python version 3.2 or later is needed for this script')
    exit(1)

sys.path.insert(0, 'lib')
del sys

# Project imports
from lib.WebController import WebController

import tornado.web
import tornado.ioloop
import tornado.httpserver
import tornado.log

# System imports
import os
import logging
import re
import random
import psycopg2

WEB_ERROR_MESSAGE = 'Oops. Something wrong happened. :)'

class Logger(logging.getLoggerClass()):

    def __init__(self, name):
        super().__init__(name)
        self.logger = logging.getLogger("scoreboard_logger")
        self.logger.setLevel(logging.ERROR)

        error_file = logging.FileHandler("logs/errors.log", encoding="utf-8")
        error_file.setLevel(logging.ERROR)
        error_formatter = logging.Formatter('%(asctime)s - %(message)s')
        error_file.setFormatter(error_formatter)

        info_file = logging.FileHandler("logs/infos.log", encoding="utf-8")
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

    def initialize(self, sponsors_imgs, logger, debug=False):
        self._debug = debug
        self._client = None
        self._logger = logger
        self._team_name = None
        self._team_ip = None
        self.remote_ip = self.request.headers.get('X-Forwarded-For', self.request.headers.get('X-Real-Ip', self.request.remote_ip))
        self._team_score = None
        self._sponsors = sponsors_imgs
        self._insults = [
            "Just what do you think you're doing Dave?",
            "It can only be attributed to human error.",
            "That's something I cannot allow to happen.",
            "Take a stress pill and think things over.",
            "This mission is too important for me to allow you to jeopardize it.",
            "Wrong!  You cheating scum!",
            "Are you on drugs?",
            "You type like i drive.",
            "Listen, broccoli brains, I don't have time to listen to this trash.",
            "I've seen penguins that can type better than that.",
            "What, what, what, what, what, what, what, what, what, what?",
            "I think ... err ... I think ... I think I'll go home"
        ]

    def write_error(self, status_code, **kwargs):
        # Handler for all the internals Error (500)
        # Handle every exception thrown by any BaseHadler
        import traceback

        if self._debug:
            exc_type, exc_obj, exc_tb = kwargs["exc_info"]
            msg = "{}".format(exc_obj)
        else:
            msg = WEB_ERROR_MESSAGE

        # self.logger.error("{}:{}:{}".format(self.request.remote_ip,
        #                                    exc_type.__name__,
        #                                    exc_obj.message))
        self.render("templates/error.html", error_msg=msg)

    def _connect(self):
        try:
            self.client = WebController()
        except psycopg2.Error as e:
            self.logger.error(e)
            message = e.pgerror
            self.renderCriticalFailure(error_msg=message)
        except Exception as e:
            self.set_status(500)
            self.logger.error(e)
            self.render('templates/error.html', error_msg="Error")

    def _getTeamInfo(self):
        try:
            team_info = list(self.client.getTeamInfoFromIp(self.remote_ip))
            self.team_name = team_info[1][1]
            self.team_ip = team_info[3][1]
            self.team_score = team_info[7][1]
        except psycopg2.Error as e:
            self.logger.error(e)
            self.team_name = "None"
            self.team_ip = "None"
            self.team_score = "None"
            message = WEB_ERROR_MESSAGE
            super().render('templates/error.html', 
                          error_msg=message,
                          team_name=self.team_name,
                          team_ip=self.team_ip,
                          team_score=self.team_score)
        except Exception as e: 
            self.logger.error(e)
            self.team_name = "None"
            self.team_ip = "None"
            self.team_score = "None"

    def _disconnect(self):
        try:
            self.client.close()
        except Exception as e:
            self.logger.error('Could not close DB connection.')
            pass  # The connection was never established

    def prepare(self):
        self._connect()

    def on_finish(self):
        self._disconnect()

    def renderCriticalFailure(self, **kwargs):
        template_name = 'templates/error.html'
        super().render(template_name,
                       team_name='None',
                       team_ip='None',
                       team_score='None',
                       **kwargs)

    def render(self, template_name, **kwargs):
        self._getTeamInfo()
        super().render(template_name,
                       team_name=self.team_name,
                       team_ip=self.team_ip,
                       team_score=self.team_score,
                       **kwargs)

    def getInsult(self, index):
        return self._insults[index]

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
        except psycopg2.Error as e:
            self.logger.error(e)
            self.render('templates/error.html', error_msg=WEB_ERROR_MESSAGE)
        except Exception as e:
            self.set_status(500)
            self.logger.error(e)
            self.render('templates/error.html', error_msg="Error")
        else:
            self.render('templates/score.html', score_table=list(score))


class ChallengesHandler(BaseHandler):
    @tornado.web.addslash
    def get(self):
        try:
            categories = self.client.getCatProgressFromIp(self.remote_ip)
            challenges = self.client.getFlagProgressFromIp(self.remote_ip)
        except psycopg2.Error as e:
            self.logger.error(e)
            self.render('templates/error.html', error_msg=WEB_ERROR_MESSAGE)
        except Exception as e:
            self.set_status(500)
            self.logger.error(e)
            self.render('templates/error.html', error_msg="Error")
        else:
            self.render('templates/challenges.html',
                        cat=list(categories),
                        chal=list(challenges))


class IndexHandler(BaseHandler):

    @tornado.web.addslash
    def get(self):
        try:
            score = self.client.getScore(top=15)
            valid_news = self.client.getNewsList()
        except psycopg2.Error as e:
            self.logger.error(e)
            self.render('templates/error.html', error_msg=WEB_ERROR_MESSAGE)
        except Exception as e:
            self.set_status(500)
            self.logger.error(e)
            self.render('templates/error.html', error_msg="Error")
        else:
            self.render('templates/index.html',
                        table=score,
                        news=valid_news,
                        sponsors=self.sponsors)

    def post(self):
        flag = self.get_argument("flag")
        valid_news = self.client.getNewsList()

        try:
            submit_message = self.client.submitFlagFromIp(
                flag,
                self.remote_ip)

        except psycopg2.Error as e:  # already submitted, invalid flag = insult
            self.logger.error(e)
            if e.pgerror.startswith('ERROR:  Invalid flag'):
                rand = random.randint(0, len(self._insults)-1)
                submit_message = e.pgerror + "!  " + self.getInsult(rand)
            elif e.pgerror.startswith('ERROR:  duplicate key'):
                submit_message = 'Flag already submitted'
            else:
                submit_message = WEB_ERROR_MESSAGE
            flag_is_valid = False
        except Exception as e:
            self.logger.error(e)
            self.set_status(500)
            self.render('templates/error.html', error_msg="Error")
        else:
            # submit_message = "Flag successfully submitted"
            flag_is_valid = True

        match = re.search("^(FLAG\-|flag\-)", flag)
        if match:
            submit_message = "Are you fucking kidding me ? " + \
              "\"Your flag without 'FLAG-'\""
	
        score = self.client.getScore(top=15)
        self.render('templates/index.html',
                    table=score,
                    news=valid_news,
                    sponsors=self.sponsors,
                    flag_is_valid=flag_is_valid,
                    submit_message=submit_message)


class DashboardHandler(BaseHandler):

    @tornado.web.addslash
    def get(self):
        try:
            jsArray2 = ""
            jsArray = self.client.getCsvScoreProgress()
            # Formatting into javascript string.
            for i in jsArray.split("\r\n"):
                jsArray2 += "\"" + i + "\\n\" + \n"
            jsArray = jsArray2[:-12]
        except psycopg2.Error as e:
            self.logger.error(e)
            self.render('templates/error.html', error_msg=WEB_ERROR_MESSAGE)
        except Exception as e:
            self.set_status(500)
            self.logger.error(e)
            self.render('templates/error.html', error_msg="Error")
        else:
            self.render('templates/dashboard.html',
                        sponsors=self.sponsors,
                        jsArray=jsArray)


class BlackMarketItemHandler(BaseHandler):

    @tornado.web.addslash
    def get(self):
        privateId = self.get_argument("privateId")

        try:
            bmItemData = self.client.getBMItemDataFromIp(privateId,
                                                         self.remote_ip
                                                         )
        except psycopg2.Error as e:
            self.logger.error(e)
            self.render('templates/error.html', error_msg=WEB_ERROR_MESSAGE)
        except Exception as e:
            self.set_status(500)
            self.logger.error(e)
            self.render('templates/error.html', error_msg="Error")
        else:
            self.set_header('Content-Type', 'application/octet-stream')
            self.set_header('Content-Disposition',
                            'attachment; filename=' + privateId)
            # buf_size = 4096
            # while True:
            #     data = bmItemData.read(buf_size)        # to test
            #     if not data:
            #         break
            self.write(bmItemData)
            self.finish()


class Error404Handler(BaseHandler):

    def initialize(self):
        self._client = None
        self._team_name = None
        self._team_ip = None
        self._team_score = None

    def get(self):
        # Cedrick Chaput don't want me to tell you when you're wrong
        self.redirect('/')


class RulesHandler(BaseHandler):

    def get(self):
        self.render('templates/rules.html')


class IndexProjectorHandler(BaseHandler):

    @tornado.web.addslash
    def get(self):
        try:
            score = self.client.getScore(top=15)
            valid_news = self.client.getNewsList()
        except psycopg2.Error as e:
            self.logger.error(e)
            self.render('templates/error.html', error_msg=WEB_ERROR_MESSAGE)
        except Exception as e:
            self.set_status(500)
            self.logger.error(e)
            self.render('templates/error.html', error_msg="Error")
        else:
            self.render('templates/projector.html',
                        table=score,
                        news=valid_news)


class DashboardProjectorHandler(BaseHandler):

    @tornado.web.addslash
    def get(self):
        try:
            jsArray2 = ""
            jsArray = self.client.getCsvScoreProgress()
            # Formatting into javascript string.
            for i in jsArray.split("\r\n"):
                jsArray2 += "\"" + i + "\\n\" + \n"
            jsArray = jsArray2[:-12]
        except psycopg2.Error as e:
            self.logger.error(e)
            self.render('templates/error.html', error_msg=WEB_ERROR_MESSAGE)
        except Exception as e:
            self.set_status(500)
            self.logger.error(e)
            self.render('templates/error.html', error_msg="Error")
        else:
            self.render('templates/projector_js.html',
                        jsArray=jsArray)


class SponsorsProjectorHandler(BaseHandler):

    @tornado.web.addslash
    def get(self):
        self.render('templates/projector_sponsors.html',
                    sponsors=self.sponsors)

if __name__ == '__main__':
    # For the CSS
    root = os.path.dirname(__file__)

    # Prety stdout logs
    tornado.log.enable_pretty_logging()

    sponsors_imgs_path = os.path.join(os.path.dirname(__file__),
                                      "static/sponsors")
    sponsors_imgs = ["/static/sponsors/" +
                     f for f in os.listdir(sponsors_imgs_path)
                     if os.path.isfile(os.path.join(sponsors_imgs_path, f))]

    logger = Logger("HF2k15_Logger")

    args = dict(logger=logger, sponsors_imgs=sponsors_imgs, debug=False)

    app = tornado.web.Application([
            (r"/", IndexHandler, args),
            (r"/challenges/?", ChallengesHandler, args),
            (r"/scoreboard/?", ScoreHandler, args),
            (r"/dashboard/?", DashboardHandler, args),
            (r"/rules/?", RulesHandler, args),
            (r"/bmi/?", BlackMarketItemHandler, args),
            (r"/projector/1/?", IndexProjectorHandler, args),
            (r"/projector/2/?", DashboardProjectorHandler, args),
            (r"/projector/3/?", SponsorsProjectorHandler, args)
        ],
         debug=True,
         static_path=os.path.join(root, 'static'),
         default_handler_class=Error404Handler  # 404 Handling
         )

    server = tornado.httpserver.HTTPServer(app,
                                           xheaders=True
                                           )

    server.listen(5000)
    tornado.ioloop.IOLoop.instance().start()

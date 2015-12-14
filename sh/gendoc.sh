#!/bin/bash
ROOT_FOLDER='../'
python2.7 /usr/local/bin/epydoc -v --graph=all -o $ROOT_FOLDER''docs --html $ROOT_FOLDER''lib/*.py 

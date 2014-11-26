#!/bin/bash
ROOT_FOLDER='../'
/usr/bin/epydoc -v --graph=all -o $ROOT_FOLDER''docs --html $ROOT_FOLDER''lib/*.py 

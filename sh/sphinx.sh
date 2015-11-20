#!/bin/bash
sphinx-apidoc -o sphinx_config -f ./
cd sphinx_config && make html

#!/bin/bash


curl -s -X POST -H "Content-Type: application/json" -d "{ \"thedog\": \"remote\" }" http://10.0.0.21:25801/48


printf '\033[0;96mExecuted successfully\033[0m\n'
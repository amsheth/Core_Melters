#!/bin/bash

diff $1 $2 > spike/diff.log
retval=$?

set -e

if [ $retval -eq "0" ]; then
    echo -e "\033[0;32mSpike diff Passed \033[0m"
    exit 0
else
    echo -e "\033[0;31mSpike diff Failed \033[0m"
    echo "first 10 lines of spike diff:"
    head -n 10 spike/diff.log
    exit $retval
fi

#/bin/bash

set -e

cd vcs
sed -nr 's/Monitor: (Total|Segment) Time: +?([0-9]+?)$$/\2/p' simulation.log

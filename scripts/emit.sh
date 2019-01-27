#!/bin/bash

# parse-english
# -- A minimum viable English parser implemented in LexYacc
# Copyright (C) 2011 onlyuser <mailto:onlyuser@gmail.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.

show_help()
{
    echo "Usage: `basename $0` <EXEC> <EXEC_FLAGS> <INPUT_MODE={xml|file|stin|arg}> <INPUT_FILE> <OUTPUT_FILE>"
}

if [ $# -ne 5 ]; then
    echo "fail! -- expect 5 arguments! ==> $@"
    show_help
    exit 1
fi

EXEC=$1
EXEC_FLAGS=$2
INPUT_MODE=$3
INPUT_FILE=$4
OUTPUT_FILE=$5

if [ ! -f $INPUT_FILE ]; then
    echo "fail! -- INPUT_FILE not found! ==> $INPUT_FILE"
    exit 1
fi

case $INPUT_MODE in
    "xml")
        $EXEC $EXEC_FLAGS -i $INPUT_FILE | tee $OUTPUT_FILE
        ;;
    "file")
        $EXEC $EXEC_FLAGS -f $INPUT_FILE | tee $OUTPUT_FILE
        ;;
    "stdin")
        cat $INPUT_FILE | $EXEC $EXEC_FLAGS | tee $OUTPUT_FILE
        ;;
    "arg")
        $EXEC $EXEC_FLAGS -e "`cat $INPUT_FILE`" | tee $OUTPUT_FILE
        ;;
    *)
        echo "fail! -- invalid input mode"
        exit 1
        ;;
esac

#echo "success!"

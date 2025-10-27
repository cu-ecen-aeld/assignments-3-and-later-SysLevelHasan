#!/bin/sh
# Tester script for assignment 3
# Author: Syed Hasan Askari Rizvi

set -e
set -u

NUMFILES=10
WRITESTR=AELD_IS_FUN
WRITEDIR=/tmp/aeld-data
username=$(cat conf/username.txt)

# Determine assignment level
assignment=$(cat ../conf/assignment.txt)

# Detect if we are running in Buildroot target or natively
if [ -d "/usr/bin" ] && [ -f "/usr/bin/writer" ]; then
    # Running on target filesystem
    BINDIR=/usr/bin
else
    # Running natively on host
    BINDIR=$(pwd)
fi

if [ $# -lt 3 ]
then
    echo "Using default value ${WRITESTR} for string to write"
    if [ $# -lt 1 ]
    then
        echo "Using default value ${NUMFILES} for number of files to write"
    else
        NUMFILES=$1
    fi
else
    NUMFILES=$1
    WRITESTR=$2
    WRITEDIR=/tmp/aeld-data/$3
fi

MATCHSTR="The number of files are ${NUMFILES} and the number of matching lines are ${NUMFILES}"

echo "Writing ${NUMFILES} files containing string ${WRITESTR} to ${WRITEDIR}"

rm -rf "${WRITEDIR}"

# Create $WRITEDIR if not assignment1
if [ $assignment != 'assignment1' ]
then
    mkdir -p "$WRITEDIR"

    if [ -d "$WRITEDIR" ]
    then
        echo "$WRITEDIR created"
    else
        exit 1
    fi
fi

echo "Cleaning and rebuilding writer"
make clean
make

# Use writer binary (not script)
for i in $(seq 1 $NUMFILES)
do
    ${BINDIR}/writer "$WRITEDIR/${username}$i.txt" "$WRITESTR"
done

# Run finder.sh (location depends on host vs target)
OUTPUTSTRING=$(${BINDIR}/finder.sh "$WRITEDIR" "$WRITESTR")

# Remove temporary directories
rm -rf /tmp/aeld-data

set +e
echo ${OUTPUTSTRING} | grep "${MATCHSTR}"
if [ $? -eq 0 ]; then
    echo "success"
    exit 0
else
    echo "failed: expected  ${MATCHSTR} in ${OUTPUTSTRING} but instead found"
    exit 1
fi

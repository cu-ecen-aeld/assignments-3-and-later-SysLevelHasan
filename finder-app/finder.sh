#!/bin/sh

# Check if both arguments are provided
if [ $# -ne 2 ]; then
    echo "Error: Two arguments required."
    echo "Usage: $0 <filesdir> <searchstr>"
    exit 1
fi

filesdir=$1
searchstr=$2

# Check if filesdir exists and is a directory
if [ ! -d "$filesdir" ]; then
    echo "Error: '$filesdir' is not a valid directory."
    exit 1
fi

# Count total number of files (recursively)
file_count=$(find "$filesdir" -type f | wc -l)

# Count number of matching lines containing searchstr
line_count=$(grep -r "$searchstr" "$filesdir" | wc -l)

# Print the result
echo "The number of files are $file_count and the number of matching lines are $line_count"

exit 0

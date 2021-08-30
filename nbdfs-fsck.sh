#!/bin/bash

if [ $# -eq 0 ]; then
	printf "usage: nbdfs-verify DIR\n"
	#printf "usage: nbdfs-verify --repair DIR\n"
	exit 1
fi

REPAIR=false
if [ "$1" = '--repair' ]; then
	REPAIR=true
	shift
fi

if [ -d "$1" ]; then
	. "$1"/config.txt
	if $REPAIR; then
		find "$1" -type f ! -name config.txt -exec "$0" --repair {} "$BLOCK_SIZE" \;
	else
		find "$1" -type f ! -name config.txt -exec "$0" {} "$BLOCK_SIZE" \;
	fi
else
	SIZE=$(stat -c %s "$1")
	if [ "$SIZE" != "$2" ]; then
		printf "Incorrect size of $SIZE for \"$1\" which should be $2\n"
		if $REPAIR; then
			printf "Correcting size of \"$1\" to $2\n"
			dd if=/dev/zero bs=1 count=0 seek="$2" of="$1" > /dev/null 2> /dev/null
		fi
	fi
fi

#!/bin/bash

if [ $# != 3 ]; then
	printf "usage: nbdfs-mkfs.sh BLOCK_SIZE BLOCKS DESTINATION\n"
	printf "usage: nbdfs-mkfs.sh 1048576 1048576 /mnt/cloud/nbdfs # 1TiB\n"
	printf "usage: nbdfs-mkfs.sh 1048576 1073741824 /mnt/cloud/nbdfs # 1PiB\n"
	exit 1
fi

BLOCK_SIZE="$1"
BLOCKS="$2"
DEST="$3"

mkdir -p "$DEST"
printf "VERSION=1\n" > "$DEST/config.txt"
printf "BLOCK_SIZE=$BLOCK_SIZE\n" >> "$DEST/config.txt"
printf "BLOCKS=$BLOCKS\n" >> "$DEST/config.txt"

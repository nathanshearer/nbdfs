Compile nbdkit on Gentoo
	cd /root
	tar xvpf nbdkit-1.27.2.tar.gz
	cd nbdkit-1.27.2
	autoreconf -i
	./configure --disable-rust CFLAGS='-w'
	make
	make check

nbdfs version 1 structure
	Fixed tree depth
	Bash supports 64-bit signed integers, largest positive value is 2**63-1 = 9223372036854775807 (approx 9EB)
	Root folder contains a config.txt file with these shell variables:
		VERSION=1
		BLOCK_SIZE=1048576 # 1MiB
		BLOCKS=1048576     # 1TiB with with 1MiB block size
	Root folder contains up to 1000 sub-folders, 000-999
	Root folder contains 3 levels of folders with blocks at the bottom only:
		root/config.txt
		root/000/000/000/000.bin
		root/999/999/999/999.bin
	Missing files are treated as 0x00 blocks

Usage:
	# /root/nbdfs-mkfs.sh 1048576 1073741824 /mnt/cloud/nbdfs
	# /root/nbd.start /mnt/cloud/nbdfs
	# parted /dev/nbd0 p
	Error: /dev/nbd0: unrecognised disk label
	Model: Unknown (unknown)                                                  
	Disk /dev/nbd0: 1126TB
	Sector size (logical/physical): 512B/512B
	Partition Table: unknown
	Disk Flags:
	# hdparm -t /dev/nbd0
	/dev/nbd0:
	Timing buffered disk reads:  94 MB in  3.06 seconds =  30.68 MB/sec

#!/usr/bin/env bash
#
# Example Bash plugin.
#
# This example can be freely used for any purpose.
#
# Run it from the build directory like this:
#
#   ./nbdkit -f -v sh ./plugins/sh/example.sh file=disk.img
#
# The -f -v arguments are optional.  They cause the server to stay in
# the foreground and print debugging, which is useful when testing.

# Note that the exit code of the script matters:
#  0 => OK
#  1 => Error
#  2 => Method is missing
#  3 => False
# For other values, see the nbdkit-sh-plugin(3) manual page.

# Check we're being run from nbdkit.
#
# Because the script has to be executable (for nbdkit to run it) there
# is a danger that someone could run the script standalone which won't
# work.  Use two tests to try to make sure we are run from nbdkit:
#
# - $tmpdir is set to a random, empty directory by nbdkit.  Note the
# contents are deleted when nbdkit exits.
#
# - $1 is set (to a method name).



function nbdfs_read
{
	local NBDFS_ROOT="$1"
	local OFFSET=$2 # in bytes
	local SIZE=$3 # in bytes

	local BEGIN=$OFFSET
	local END=$(($OFFSET+$SIZE))

	local NEXT=0
	while [ "$BEGIN" -lt "$END" ]; do
		NEXT=$(( ($BEGIN/$BLOCK_SIZE+1)*$BLOCK_SIZE ))
		if [ $NEXT -lt $END ]; then
			nbdfs_read_block $NBDFS_ROOT $BEGIN $(($NEXT-$BEGIN)) || return 1
		else
			nbdfs_read_block $NBDFS_ROOT $BEGIN $(($END-$BEGIN)) || return 1
		fi
		BEGIN=$NEXT
	done
}

function nbdfs_read_block
{
	local NBDFS_ROOT="$1"
	local OFFSET=$2 # in bytes
	local SIZE=$3 # in bytes

	local REMAINDER=$(($OFFSET))
	local BLOCK_1=$(( $REMAINDER / ($BLOCK_SIZE*1000000000) ))
	REMAINDER=$(( $REMAINDER % ($BLOCK_SIZE*1000000000) ))
	local BLOCK_2=$(( $REMAINDER / ($BLOCK_SIZE*1000000) ))
	REMAINDER=$(( $REMAINDER % ($BLOCK_SIZE*1000000) ))
	local BLOCK_3=$(( $REMAINDER / ($BLOCK_SIZE*1000) ))
	REMAINDER=$(( $REMAINDER % ($BLOCK_SIZE*1000) ))
	local BLOCK_4=$(($REMAINDER / $BLOCK_SIZE))
	OFFSET=$(($REMAINDER % $BLOCK_SIZE))

	local BLOCK=$(printf %03d/%03d/%03d/%03d $BLOCK_1 $BLOCK_2 $BLOCK_3 $BLOCK_4)
	#logger "read $NBDFS_ROOT/$BLOCK $OFFSET $SIZE"

	if [ -e "$NBDFS_ROOT/$BLOCK" ]; then
		dd iflag=skip_bytes,count_bytes if="$NBDFS_ROOT/$BLOCK" skip="$OFFSET" count="$SIZE" 2> /dev/null || return 1
	else
		dd iflag=skip_bytes,count_bytes if=/dev/zero skip="$OFFSET" count="$SIZE"  2> /dev/null || return 1
	fi
}

function nbdfs_write
{
	local NBDFS_ROOT="$1"
	local OFFSET=$2 # in bytes
	local SIZE=$3 # in bytes

	local BEGIN=$OFFSET
	local END=$(($OFFSET+$SIZE))

	local NEXT=0
	while [ "$BEGIN" -lt "$END" ]; do
		NEXT=$(( ($BEGIN/$BLOCK_SIZE+1)*$BLOCK_SIZE ))
		if [ $NEXT -lt $END ]; then
			nbdfs_write_block $NBDFS_ROOT $BEGIN $(($NEXT-$BEGIN)) || return 1
		else
			nbdfs_write_block $NBDFS_ROOT $BEGIN $(($END-$BEGIN)) || return 1
		fi
		BEGIN=$NEXT
	done
}

function nbdfs_write_block
{
	local NBDFS_ROOT="$1"
	local OFFSET=$2 # in bytes
	local SIZE=$3 # in bytes

	local REMAINDER=$(($OFFSET))
	local B1=$( printf %03d $(( $REMAINDER / ($BLOCK_SIZE*1000000000) )) )
	REMAINDER=$(( $REMAINDER % ($BLOCK_SIZE*1000000000) ))
	local B2=$( printf %03d $(( $REMAINDER / ($BLOCK_SIZE*1000000) )) )
	REMAINDER=$(( $REMAINDER % ($BLOCK_SIZE*1000000) ))
	local B3=$( printf %03d $(( $REMAINDER / ($BLOCK_SIZE*1000) )) )
	REMAINDER=$(( $REMAINDER % ($BLOCK_SIZE*1000) ))
	local B4=$( printf %03d $(($REMAINDER / $BLOCK_SIZE)) )
	OFFSET=$(($REMAINDER % $BLOCK_SIZE))

	if [ ! -e "$NBDFS_ROOT/$B1/$B2/$B3/$B4" ]; then
		#logger "create $NBDFS_ROOT/$B1/$B2/$B3/$B4 $OFFSET $SIZE"
		# multiple threads can attempt to create and overwrite the same file
		# create then atomically move into place
		# delete unmoved files
		mkdir -p "$NBDFS_ROOT/$B1/$B2/$B3"
		#local UUID=$(uuidgen)
		#dd if=/dev/zero bs=$BLOCK_SIZE count=1 of="$NBDFS_ROOT/$B1-$B2-$B3-$B4.$UUID" || return 1
		#mv -nv "$NBDFS_ROOT/$B1-$B2-$B3-$B4.$UUID" "$NBDFS_ROOT/$B1/$B2/$B3/$B4"
		#rm -f "$NBDFS_ROOT/$B1-$B2-$B3-$B4.$UUID"

		# this works but is very slow
		#dd if=/dev/zero bs=1 count=$BLOCK_SIZE of="$NBDFS_ROOT/$B1/$B2/$B3/$B4" || return 1

		# this works but is very slow over sshfs
		#dd iflag=count_bytes if=/dev/zero count=$BLOCK_SIZE of="$NBDFS_ROOT/$B1/$B2/$B3/$B4"
		
		# this is much faster
		# use fsync to force a buffer flush and detect any IO errors: https://abbbi.github.io/dd/
		dd if=/dev/zero bs=1 count=0 seek=$BLOCK_SIZE of="$NBDFS_ROOT/$B1/$B2/$B3/$B4" conv=fsync > /dev/null 2> /dev/null
	fi
	#logger "write $NBDFS_ROOT/$B1/$B2/$B3/$B4 $OFFSET $SIZE"

	# this works but is very slow
	#dd bs=1 ibs=1048576 obs=1048576 conv=notrunc seek=$OFFSET count=$SIZE of="$NBDFS_ROOT/$B1/$B2/$B3/$B4" ||

	# this is much faster
	# use fsync to force a buffer flush and detect any IO errors: https://abbbi.github.io/dd/
	# note that dd does not have a oflag for count_bytes so this pipe is required
	dd iflag=count_bytes count=$SIZE 2>/dev/null | dd oflag=seek_bytes conv=notrunc,fsync seek=$OFFSET of="$NBDFS_ROOT/$B1/$B2/$B3/$B4" > /dev/null 2> /dev/null
}

if [ ! -d $tmpdir ] || [ "x$1" = "x" ]; then
	echo "$0: this script must be run from nbdkit" >&2
	echo "Use ‘nbdkit sh $0’" >&2
	exit 1
fi

# We make a symlink to the file in the tmpdir directory.
f=$tmpdir/nbdfs
NBDFS="$tmpdir/nbdfs"

case "$1" in
	dump_plugin)
		# This is called from: nbdkit sh example.sh --dump-plugin
		echo "example_sh=1"
		;;

	config)
		# We expect a file=... parameter pointing to the file to serve.
		if [ "$2" = "file" ]; then
			if [ ! -r "$3" ]; then
				echo "file $3 does not exist or is not readable" >&2
				exit 1
			fi
			ln -sf "$(realpath "$3")" $f
			cp "$3/config.txt" "$tmpdir"
		else
			echo "unknown parameter $2=$3" >&2
			exit 1
		fi
		;;

	config_complete)
		# Check the file parameter was passed.
		if [ ! -L $f ]; then
			echo "file parameter missing" >&2
			exit 1
		fi
		;;

	thread_model)
		#echo parallel
		;;

	list_exports | default_export)
		# The following lists the names of all files in the current
		# directory that do not contain whitespace, backslash, or single
		# quotes.  No description accompanies the export names.
		# The first file listed is used when a client requests export ''.
		find . -type f \! -name "*['\\\\[:space:]]*"
		;;

	open)
		# Open a new client connection.
		# This plugin is stateless, so do nothing
		;;

	get_size)
		# Print the disk size in bytes on stdout.
		source "$tmpdir/config.txt"
		printf $(($BLOCK_SIZE*$BLOCKS))
		#stat -L -c '%s' $f || exit 1
		;;

	pread)
		source "$tmpdir/config.txt"
		# Read the requested part of the disk and write to stdout.
		nbdfs_read "$NBDFS" "$4" "$3" || exit 1
		;;

	pwrite)
		source "$tmpdir/config.txt"
		# Copy data from stdin and write it to the disk.
		nbdfs_write "$NBDFS" $4 $3 || exit 1
		;;

	can_write)
		# If we provide a pwrite method, we must provide this method
		# (and similarly for flush and trim).  See nbdkit-sh-plugin(3)
		# for details.  This will exit 0 (below) which means true.
		# Use ‘exit 3’ if false.
		;;

	trim)
		# Punch a hole in the backing file, if supported.
		#fallocate -p -o $4 -l $3 -n $f || exit 1
		;;

	can_trim)
		exit 3
		# We can trim if the fallocate command exists.
		#fallocate --help >/dev/null 2>&1 || exit 3
		;;

	zero)
		# Efficiently zero the backing file, if supported.
		# Try punching a hole if flags includes may_trim, otherwise
		# request to leave the zeroed range allocated.
		# Attempt a fallback to write on any failure, but this requires
		# specific prefix on stderr prior to any message from fallocate;
		# exploit the fact that stderr is ignored on success.
		#echo ENOTSUP >&2
		#case ,$5, in
		#	*,may_trim,*) fallocate -p -o $4 -l $3 -n $f || exit 1 ;;
		#	*)            fallocate -z -o $4 -l $3 -n $f || exit 1 ;;
		#esac
		;;

	can_zero)
		exit 3
		# We can efficiently zero if the fallocate command exists.
		#fallocate --help >/dev/null 2>&1 || exit 3
		;;

	# cache)
		# Implement an efficient prefetch, if desired.
		# It is intentionally omitted from this example.
		# dd iflag=skip_bytes,count_bytes skip=$4 count=$3 \
		#    if=$f of=/dev/null || exit 1
		# ;;

	can_cache)
		# Caching is not advertised to the client unless can_cache prints
		# a tri-state value.  Here, we choose for caching to be a no-op,
		# by omitting counterpart handling for 'cache'.
		echo native
		;;

	extents)
		# Report extent (block status) information as 'offset length [type]'.
		# This example could omit the handler, since it just matches
		# the default behavior of treating everything as data; but if
		# your code can detect holes, this demonstrates the usage.
		echo "$4           $(($3/2)) 0"
		echo "$(($4+$3/2)) $(($3/2))"
		# echo "$4 $3 hole,zero"
		;;

	can_extents)
		# Similar to can_write
		;;

	*)
		# Unknown methods must exit with code 2.
		exit 2
esac

exit 0

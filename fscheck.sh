#!/bin/bash
BLKDEV=$1
CASE=$2
[ -z "$BLKDEV" ] && exit
[ -z "$CASE" ] && exit

#return to image corrupted
cp testcases/bak/* testcases/

vmtouch -e $(which e2fsck) > /dev/null 2>&1
vmtouch -e $(which tune2fs) > /dev/null 2>&1
vmtouch -e $(which dd) > /dev/null 2>&1
vmtouch -e -f $(which awk) > /dev/null 2>&1
vmtouch -e testcases > /dev/null 2>&1

BEFORE_IO=($(cat /sys/block/sda/sda2/stat))
BEFORE=$(($(date +%s%N)/1000000))

if [ "$CASE" == "0" ]; then
	echo "Aging"
	FS_STATE=`tune2fs -l $BLKDEV | awk 'BEGIN { FS=":"; need_fsck=0 } /^Filesystem features/ && /has_journal/ && /needs_recovery/ { need_fsck=1 } /^Filesystem state/ {gsub (" ","", $0); if ( $2 != "clean" ) need_fsck=2 } END { print need_fsck }'`
	FS_STATE=`e2fsck -n $BLKDEV 2> /dev/null | awk 'BEGIN { need_fsck=0; } /check forced/ { need_fsck=1; } END { print need_fsck }'`
	FS_STATE=`e2fsck -y $BLKDEV 2> /dev/null | awk 'BEGIN { need_fsck=0; } /check forced/ { need_fsck=1; } END { print need_fsck }'`
	TEMP=`dd if=$BLKDEV bs=1 count=2 skip=$((1024+0x3A)) 2>/dev/null | od -An -t d2 | tr -d " "`
	TEMP2=`dd if=$BLKDEV bs=1 count=4 skip=$((1024+0x60)) 2>/dev/null | od -An -t d4 | tr -d " "`
	exit
elif [ "$CASE" == "1" ]; then
	FS_STATE=`tune2fs -l $BLKDEV | awk 'BEGIN { FS=":"; need_fsck=0 } /^Filesystem features/ && /has_journal/ && /needs_recovery/ { need_fsck=1 } /^Filesystem state/ {gsub (" ","", $0); if ( $2 != "clean" ) need_fsck=2 } END { print need_fsck }'`
elif [ "$CASE" == "2" ]; then
	FS_STATE=`e2fsck -n $BLKDEV 2> /dev/null | awk 'BEGIN { need_fsck=0; } /check forced/ { need_fsck=1; } END { print need_fsck }'`
elif [ "$CASE" == "3" ]; then
	FS_STATE=`e2fsck -y $BLKDEV 2> /dev/null | awk 'BEGIN { need_fsck=0; } /check forced/ { need_fsck=1; } END { print need_fsck }'`
elif [ "$CASE" == "4" ]; then
	TEMP=`dd if=$BLKDEV bs=1 count=2 skip=$((1024+0x3A)) 2>/dev/null | od -An -t d2 | tr -d " "`
	#0x0001	Cleanly umounted
	#0x0002	Errors detected
	#0x0004	Orphans being recovered
	(((((TEMP&0x1)==0)) || ((TEMP&0x2)) || ((TEMP&0x4)))) && FS_STATE=1 || FS_STATE=0
elif [ "$CASE" == "5" ]; then
	TEMP=`dd if=$BLKDEV bs=1 count=2 skip=$((1024+0x3A)) 2>/dev/null | od -An -t d2 | tr -d " "`
	#0x1	Cleanly umounted
	#0x2	Errors detected
	#0x4	Orphans being recovered
	TEMP2=`dd if=$BLKDEV bs=1 count=4 skip=$((1024+0x60)) 2>/dev/null | od -An -t d4 | tr -d " "`
	#0x4	Filesystem needs recovery (INCOMPAT_RECOVER).
	(((((TEMP&0x1)==0)) || ((TEMP&0x2)) || ((TEMP&0x4)) || ((TEMP2&0x4)))) && FS_STATE=1 || FS_STATE=0
fi
MIDDLE_1=$(($(date +%s%N)/1000000))

if [ "$FS_STATE" != "0" ]; then
	e2fsck -y $BLKDEV > /dev/null 2>&1 || true
fi

MIDDLE_2=$(($(date +%s%N)/1000000))
sudo mount $BLKDEV ./tt
AFTER=$(($(date +%s%N)/1000000))
AFTER_IO=($(cat /sys/block/sda/sda2/stat))

sleep 2
sudo umount ./tt

echo $FS_STATE, total:$((AFTER-BEFORE))ms, check:$((MIDDLE_1-BEFORE))ms, fix:$((MIDDLE_2-MIDDLE_1))ms, mount:$((AFTER-MIDDLE_2))ms, $((AFTER_IO[0]-BEFORE_IO[0])) read requests, $(((AFTER_IO[2]-BEFORE_IO[2])/8)) read bytes, $((AFTER_IO[3]-BEFORE_IO[3])) ticks



#!/bin/bash
HEXCONV="/home/sunghwan/bin/hexconv.sh"
BLKDEV=$1
CMD=$2

TOTAL_BLOCK="$(dd if=datafs.ext4 skip=$((1024+0x4)) bs=1 count=4 2> /dev/null | od -An -td4 | tr -d " ")"
BLOCK_PER_GROUP="$(dd if=datafs.ext4 skip=$((1024+0x20)) bs=1 count=4 2> /dev/null | od -An -td4 | tr -d " ")"
BLOCK_GROUP_NR=$((TOTAL_BLOCK/BLOCK_PER_GROUP))
FIRST_BLOCK=$(debugfs $BLKDEV -R "stats" | awk -F ":" '/First block/ { print $2 }')
EXT4_BASE_OFFSET=$((FIRST_BLOCK*4096+1024))
#Superblock size is not 4096. end offset is 0xc00
SUPER_BLOCK_SIZE=3072
#Block Group Descritor begins at end of SuperBlock
GROUP_DESCRIPTOR_BASE_OFFSET=$((EXT4_BASE_OFFSET+SUPER_BLOCK_SIZE))
GROUP_DESCRIPTOR_SIZE=32

echo $BLOCK_GROUP_NR

[ -z "$BLKDEV" ] && exit
[ -z "$CMD" ] && exit

if [ "$CMD" == "sb_magic" ] 
then
	$HEXCONV $BLKDEV $((EXT4_BASE_OFFSET+0x38)) $((0xFFFF)) 2 
elif [ "$CMD" == "sb_checksum" ] 
then
	#16 bytes
	$HEXCONV $BLKDEV $((EXT4_BASE_OFFSET+0x68)) 0 4 
	$HEXCONV $BLKDEV $((EXT4_BASE_OFFSET+0x72)) 0 4
	$HEXCONV $BLKDEV $((EXT4_BASE_OFFSET+0x76)) 0 4
	$HEXCONV $BLKDEV $((EXT4_BASE_OFFSET+0x80)) 0 4
elif [ "$CMD" == "sb_valid" ] 
then
	$HEXCONV $BLKDEV $((EXT4_BASE_OFFSET+0x3A)) 0 2
elif [ "$CMD" == "sb_error" ] 
then
	$HEXCONV $BLKDEV $((EXT4_BASE_OFFSET+0x3A)) 2 2
elif [ "$CMD" == "sb_orphans" ] 
then
	$HEXCONV $BLKDEV $((EXT4_BASE_OFFSET+0x3A)) 4 2
elif [ "$CMD" == "sb_journal_inode" ] 
then
	$HEXCONV $BLKDEV $((EXT4_BASE_OFFSET+0xE0)) 0 4
elif [ "$CMD" == "gd_checksum" ] 
then
	echo "AAA:"$GROUP_DESCRIPTOR_BASE_OFFSET
	$HEXCONV $BLKDEV $((GROUP_DESCRIPTOR_BASE_OFFSET+0x1E)) 0 2
elif [ "$CMD" == "gd_blockbitmap" ] 
then
	for i in `seq 0 $BLOCK_GROUP_NR`
	do
		cal=$((i*GROUP_DESCRIPTOR_SIZE))
		echo "GDB:"$GROUP_DESCRIPTOR_BASE_OFFSET
		echo "OFF:"$cal
		$HEXCONV $BLKDEV $((GROUP_DESCRIPTOR_BASE_OFFSET+cal)) 0 4
	done
elif [ "$CMD" == "gd_inodebitmap" ] 
then
	for i in `seq 0 $BLOCK_GROUP_NR`
	do
		cal=$((i*GROUP_DESCRIPTOR_SIZE))
		$HEXCONV $BLKDEV $((GROUP_DESCRIPTOR_BASE_OFFSET+cal+0x4)) 0 4
	done
elif [ "$CMD" == "gd_inodetable" ] 
then
	for i in `seq 0 $BLOCK_GROUP_NR`
	do
		cal=$((i*GROUP_DESCRIPTOR_SIZE))
		$HEXCONV $BLKDEV $((GROUP_DESCRIPTOR_BASE_OFFSET+cal+0x8)) 0 4
	done
elif [ "$CMD" == "gd_freeblock" ] 
then
	for i in `seq 0 $BLOCK_GROUP_NR`
	do
		cal=$((i*GROUP_DESCRIPTOR_SIZE))
		#corrupt only one byte
		$HEXCONV $BLKDEV $((GROUP_DESCRIPTOR_BASE_OFFSET+cal+0xC)) 0 2
	done
elif [ "$CMD" == "gd_freeinode" ] 
then
	for i in `seq 0 $BLOCK_GROUP_NR`
	do
		cal=$((i*GROUP_DESCRIPTOR_SIZE))
		#corrupt only one byte
		$HEXCONV $BLKDEV $((GROUP_DESCRIPTOR_BASE_OFFSET+cal+0xE)) 0 2
	done
elif [ "$CMD" == "gd_useddir" ] 
then
	for i in `seq 0 $BLOCK_GROUP_NR`
	do
		cal=$((i*GROUP_DESCRIPTOR_SIZE))
		#corrupt only one byte
		$HEXCONV $BLKDEV $((GROUP_DESCRIPTOR_BASE_OFFSET+cal+0x10)) 0 2
	done
elif [ "$CMD" == "ino_file_mode" ] 
then
	echo "ABCDE" > testfile
	for i in `seq 0 10`
	do
		debugfs -w datafs.ext4 -R "write testfile testfile$i"
		INO_LOCATION=($(debugfs datafs.ext4 -R "imap testfile$i" | awk -F ",| " '/located at block/ {print $4, $7}'))
		$HEXCONV $BLKDEV $((INO_LOCATION[0]*4096+INO_LOCATION[1])) 0 2
	done
	rm testfile

else
	echo $CMD
fi

#!/bin/bash
DEV=$1
OFFSET=$2
#third parameter should be decimal
VALUE=$3
#1(byte) or 2(short) or 4(int)
SIZE=$4

[ -z "$DEV" ] && exit
[ -z "$OFFSET" ] && exit
[ -z "$VALUE" ] && exit
[ -z "$SIZE" ] && exit

echo "DEV:$DEV"
echo "OFFSET:$OFFSET"
echo "VALUE:$VALUE"
echo "SIZE:$SIZE"

byte2bin() {
	local i=$1
	local f
	printf -v f '\\x%02' $((i&255))
	printf "$f"
}

short2bin() {
	local i=$1
	local f
	printf -v f '\\x%02x\\x%02x' $((i&255)) $((i >> 8 & 255))
	printf "$f"
}

int2bin() {
	local i=$1
	local f
	printf -v f '\\x%02x\\x%02x\\x%02x\\x%02x' $((i&255)) $((i >> 8 & 255)) $((i >> 16 & 255)) $((i >> 24 & 255))
	printf "$f"
}

if [ $SIZE == "1" ]; then
	HEX=$(byte2bin $VALUE | od -An -t x1)
elif [ $SIZE == "2" ]; then
	HEX=$(short2bin $VALUE | od -An -t x1)
elif [ $SIZE == "4" ]; then
	HEX=$(int2bin $VALUE | od -An -t x1)
fi

echo "HEX:$HEX"
echo "00:$HEX" | xxd -r > ./tmp.bin
BEFORE=$(dd if=$DEV bs=1 skip=$OFFSET count=$SIZE 2>/dev/null | od -An -t x$SIZE)
dd if=./tmp.bin of=$DEV bs=1 seek=$OFFSET count=$SIZE conv=notrunc 2>/dev/null
AFTER=$(dd if=$DEV bs=1 skip=$OFFSET count=$SIZE 2>/dev/null | od -An -t x$SIZE)
echo "BEFORE:$BEFORE --> AFTER:$AFTER"

rm ./tmp.bin

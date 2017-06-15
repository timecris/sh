#!/bin/bash
DEV="$1"
blocknr="$2"


#Super Block Number
if [[ "$DEV" =~ "loop" ]] 
then
	SBN=0
else
	SBN=$(fdisk -l | grep $DEV | awk -F " " '{ print $2 }')
fi

blocknr=$((($blocknr-$SBN)/8))
echo "$blocknr"

FLEXGROUP=$(fsstat $DEV | grep "Block Groups Per Flex Group" | awk '{print $6}')
INODE_PER_GROUP=$(fsstat $DEV | grep "Inodes per group" | awk '{print $4}')
BLOCK_PER_GROUP=$(fsstat $DEV | grep "Blocks per group" | awk '{print $4}')
INODE_SIZE=$(fsstat $DEV | grep "Inode Size:" | awk '{print $3}')
BLOCK_SIZE=$(fsstat $DEV | grep "Block Size:" | awk '{print $3}')
INODE_PER_BLOCK=$((BLOCK_SIZE/INODE_SIZE))
JOURNAL_INODE=$(fsstat $DEV | grep "Journal Inode" | awk '{print $3}')
JOURNAL_START_BLOCK=$(debugfs $DEV -R "bmap <$JOURNAL_INODE> 0")
JOURNAL_LENGTH=$(dumpe2fs $DEV | grep "Journal length" | awk '{print $3}')

db_grp_0=$(fsstat $DEV | tr -d " " | grep "Group:0:" -A 11 | grep "Databitmap" | awk -F [:-] '{printf $2}')

group=$(blkstat $DEV $blocknr | grep "Group" | awk '{print $2}')

#GroupDescriptorTable
gd=($(fsstat $DEV | tr -d " " | grep "Group:$group:" -A 11 | grep "GroupDescriptorTable" | awk -F [:-] '{printf $2" ";  print $3}'))
#GroupDescriptorGrowthBlock
gb=($(fsstat $DEV | tr -d " " | grep "Group:$group:" -A 11 | grep "GroupDescriptorGrowthBlocks" | awk -F [:-] '{printf $2" ";  print $3}'))

echo "$gd"
echo "$gb"
inode=0
inode_type=""
journal_type=""
filename=""
type=""


number_in_grp=$((group % FLEXGROUP))
#Databitmap
if (( $group >= "0" )) && (( $group < $FLEXGROUP )); then
	db_str=$db_grp_0
else
	db_str=$(( (group - (number_in_grp)) * BLOCK_PER_GROUP))
fi

db_end=$((db_str + FLEXGROUP - 1))
#InodeBitmap
ib_str=$((db_end + 1))
ib_end=$((ib_str + FLEXGROUP - 1))

it_str=$((ib_end + 1))
it_end=$((it_str + (FLEXGROUP * 512) - 1))

dk_str=$((it_end + 1))
dk_end=$((BLOCK_PER_GROUP * (group + 1) - 1))

if (( "$blocknr" == "0")); then
	inode=0
	group=0
	type="SuperBlock"
elif [[ -n ${gd[0]} ]] && (( "${gd[0]}" <= "$blocknr")) && (("${gd[1]}" >= "$blocknr" )); then
	inode=0
	type="GDT"
elif [[ -n ${gb[0]} ]] && (( "${gb[0]}" <= "$blocknr")) && (("${gb[1]}" >= "$blocknr" )); then
	inode=0
	type="GDGB"
elif (( "$db_str" <= "$blocknr")) && (("$db_end" >= "$blocknr" )); then
	inode=0
	type="DataBitmap"
elif (( "$ib_str" <= "$blocknr")) && (("$ib_end" >= "$blocknr" )); then
	inode=0
	type="InodeBitmap"
elif (( "$it_str" <= "$blocknr")) && (("$it_end" >= "$blocknr" )); then
	type="InodeTable"
	itrange[0]=$(((blocknr-it_str)*INODE_PER_BLOCK))
	itrange[1]=$((itrange[0]+INODE_PER_BLOCK))
	#echo "AAAAAAAA" ${itrange[0]}
	inode="${itrange[0]}~${itrange[1]}"
elif (( "$dk_str" <= "$blocknr")) && (("$dk_end" >= "$blocknr" )); then
	type="Data"
	#inode=$(ifind -d "$blocknr" $DEV)
	inode=$(debugfs $DEV -R "icheck $blocknr" 2>&1 | awk 'NR==3 {print $2}')

	if [[ $inode == "2" ]]; then
		inode_type="Root"
		filename="/"
	elif [[ $inode == "7" ]]; then
		inode_type="Resize"
	elif [[ $inode == "8" ]]; then
		jheader=$(xxd -p -l 1 -seek $((blocknr * BLOCK_SIZE + 7)) $DEV)
		if [[ "$jheader" == "01" ]]; then
			inode_type="JournalD"
		elif [[ "$jheader" == "02" ]]; then
			inode_type="JournalC"
		fi
	elif [[ $inode =~ ^-?[0-9]+$ ]]; then
		inode_type="Normal"
		#filename=$(ffind -u $DEV $inode)
		filename=$(debugfs $DEV -R "ncheck $inode" 2>&1 | awk 'NR==3 {print $2}')
	else 
		inode=0
		inode_type="Temp"
	fi
else 
	type="What?"
	inode=0
fi

printf '%-20s %-7s %-12s %-7s %-15s %-10s %-15s %-10s %-50s\n' ${ARR[0]} ${ARR[1]} ${ARR[2]} ${ARR[3]} $type $group $inode $inode_type $filename


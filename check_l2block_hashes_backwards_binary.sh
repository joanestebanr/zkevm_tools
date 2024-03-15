#!/bin/bash
# imports
source $(dirname $0)/lib/ansi.sh
COLOR_RPC1=$LIGHTWHITE
COLOR_RPC2=$LIGHTYELLOW
# CONFIGURATIONS
############################ MAINNET
RPC_MAINNET_TRUSTED=https://zkevm-rpc.com/
RPC_MAINNET_PLESS1=http://34.175.231.220:8545
RPC_MAINNET_PLESS2=http://34.175.237.141:8545
RPC_MAINNET_PLESS4=http://34.175.10.246:8545/
RPC_MAINNET_PLESS5=http://34.175.67.96:8545
RPC_MAINNET_PLESS6=http://34.175.164.151:8545
RPC_MAINNET_PARTNER1=https://polygon-zkevm-a.cryptomanufaktur.net/
############################## CARDONA - TESTNET(SEPOLIA)
RPC_CARDONA_TRUSTED=https://rpc.cardona.zkevm-rpc.com/
RPC_CARDONA_PLESS2=https://permissionless2.zkevm-testnet.com/


###############################################################################
# check_l2block(BLOCK_NUMBER)
# export:
# 	HASH_RPC1 - hash of the block on RPC1
# 	HASH_RPC2 - hash of the block on RPC2
# return 0 equal / 1 different
function check_l2block()
{
	local blk_number=$1
	M=$(curl -XPOST $RPC1 --header 'Content-Type: application/json' -s -d "{\"jsonrpc\":\"2.0\", \"method\":\"eth_getBlockByNumber\", \"params\":[\"$blk_number\", false], \"id\":1 }" | jq .result.hash)
	if [ $? -ne 0 ]; then
		echo "Error getting block $blk_number on RPC1: $RPC1"
		exit 1
	fi
	P=$(curl -XPOST $RPC2 --header 'Content-Type: application/json' -s -d "{\"jsonrpc\":\"2.0\", \"method\":\"eth_getBlockByNumber\", \"params\":[\"$blk_number\", false], \"id\":1 }" | jq .result.hash)
	if [ $? -ne 0 ]; then
		echo "Error getting block $blk_number on RPC2: $RPC2"
		exit 1
	fi
	export HASH_RPC1=$M
	export HASH_RPC2=$P
	if [ "$M" == "$P" ]; then
		#echo $blk_number match! $M $P
		label_per_check_l2block_result 0
		return 0
	fi
	label_per_check_l2block_result 1
	return 1
}
###############################################################################
# get_last_l2block(RPC_URL)
# export:
# 	LAST_BLOCK_RPC - last block number on the RPC
function get_last_l2block()
{
	local _rpc=$1
	export LAST_BLOCK_RPC=$(curl -XPOST $_rpc --header 'Content-Type: application/json' -s -d "{\"jsonrpc\":\"2.0\", \"method\":\"eth_blockNumber\", \"params\":[], \"id\":1 }" | jq .result | xargs -l printf %d )
}

###############################################################################
# get_starting_l2blocks()
# input: $RPC1 and $RPC2
function get_starting_l2blocks()
{	
	get_last_l2block $RPC1
	if [ $? -ne 0 ]; then
		echo "Error getting last block on RPC1: $RPC1"
		return 1
	fi
	LAST_L2BLOCK_RPC1=$LAST_BLOCK_RPC
	get_last_l2block $RPC2
	if [ $? -ne 0 ]; then
		echo "Error getting last block on RPC2: $RPC2"
		return 1
	fi
	LAST_L2BLOCK_RPC2=$LAST_BLOCK_RPC
}

function label_per_check_l2block_result()
{
	local _res=$1
	if [ $_res -eq 0  ]; then
		export CHECK_L2BLOCK_RESULT_LABEL="${LIGHTGREEN}OK  ${END_ANSI}"
	else
		export CHECK_L2BLOCK_RESULT_LABEL="${LIGHTRED}BAD ${END_ANSI}"
	fi
}

###############################################################################
# show_check_l2block_result(RESULT, BLOCK_NUMBER)
# input: $1 - result of the check_l2block
# input: $2 - block number
# output: print the result of the check_l2block
function show_check_l2block_result()
{
	local _res=$1
	local _i=$2
	if [ $_res -eq 0  ]; then
		echo -e "L2BLOCK ${COLOR_RPC1}${_i}${END_ANSI} ${LIGHTGREEN} OK${END_ANSI} ${COLOR_RPC1}$HASH_RPC1${END_ANSI} ${COLOR_RPC2}$HASH_RPC2${END_ANSI}"
	else
		echo -e "L2BLOCK ${COLOR_RPC1}${_i}${END_ANSI} ${LIGHTRED}BAD${END_ANSI} ${COLOR_RPC1}$HASH_RPC1${END_ANSI} ${COLOR_RPC2}$HASH_RPC2${END_ANSI}"
	fi
}

###############################################################################
# show_hashes(START, END)
# input: $1 - start
# input: $2 - end
# output: print the result of the check_l2block
function show_hashes()
{
	local _start=$1
	local _end=$2
	local _i=$1
	while [ $_i -gt $_end ]; do
		check_l2block $_i
		show_check_l2block_result $? $_i
		_i=$(expr $_i - 1)
	done
}

###############################################################################
function assert_precondition()
{
	local _last_l2block=$1
	# The starting point must differ
	check_l2block $_last_l2block
if [ $? -eq 0 ]; then
	echo -e Nothing to do, first block $_last_l2block is the same on both RPCs $HASH_RPC2
	show_hashes $_last_l2block $(expr $_last_l2block - 10)
	exit 0
fi
}

###############################################################################
# generic_check_error(RETURN, MESSAGE)
function generic_check_error()
{
	local _ret=$1
	local _msg=$2
	if [ $_ret -ne 0 ]; then
		echo ${RED}ERROR: ${END_ANSI} $_msg
		exit 1
	fi
}

###############################################################################
# MAIN
###############################################################################
set -o pipefail # enable strict command pipe error detection
down=1
# Get RPC1 and RPC2 from command line
RPC1=$1
RPC2=$2
if [ -z $RPC1 ] || [ -z $RPC2 ]; then
	echo "Usage: $0 <RPC1> <RPC2>"
	echo " "
	echo "Example: $0 $RPC_MAINNET_TRUSTED $RPC_MAINNET_PLESS1"
	exit 1
fi


echo -e "Comparing blocks from ${COLOR_RPC1}${RPC1}${END_ANSI} and ${COLOR_RPC2} ${RPC2} ${END_ANSI}"
get_starting_l2blocks
generic_check_error $? "Error getting starting blocks"
echo  -e "Last blocks: ${COLOR_RPC1}$LAST_L2BLOCK_RPC1${END_ANSI}  ${COLOR_RPC2}$LAST_L2BLOCK_RPC2${END_ANSI}  distance: $(expr $LAST_L2BLOCK_RPC1 - $LAST_L2BLOCK_RPC2)"
up=$LAST_L2BLOCK_RPC2
assert_precondition $up


echo RANGE from $down to $up
iterations=0
while true 
do
	iterations=$(expr $iterations + 1)
	#echo block $i
	i=$(expr \( $up - $down \) / 2)
	i=$(expr $down + $i)
	check_l2block $i
	check_result=$?
	if [ $up -lt $down ]; then
		echo last interation: $iterations _ last range: $up $down
		show_hashes $(expr $i + 5) $(expr $i - 10)
		exit 0
	fi
	printf " it: %2d ${CHECK_L2BLOCK_RESULT_LABEL} block: %7d Range: [%7d - %7d]\n" $iterations $i $down $up
	if [ $check_result -eq 0  ]; then
		down=$(expr $i + 1)
	else
		up=$(expr $i - 1) 
	fi 
	
	i=$(expr $i - 1)
done

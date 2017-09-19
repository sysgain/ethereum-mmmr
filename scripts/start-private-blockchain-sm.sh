#!/bin/bash

#############
# Parameters
#############
if [ $# -lt 2 ]; then echo "Incomplete parameters supplied. usage: \"$0 <config file path> <ethereum account passwd>\""; exit 1; fi
GETH_CFG=$1;
PASSWD=$2;
CONSORTIUM_MEMBER_ID=0
# Load config variables
if [ ! -e $GETH_CFG ]; then echo "Config file not found. Exiting"; exit 1; fi
. $GETH_CFG

echo "bootnodes are: $BOOTNODES"
declare -a BOOTNODES
BOOTNODES[0]=`echo $BOOTNODES | cut -d " " -f1`
echo "1st bootnode is: ${BOOTNODES[0]}"
BOOTNODES[1]=`echo $BOOTNODES | cut -d " " -f2`
###########################################
# Ensure that at least one bootnode is up
# If not, wait 5 seconds then retry
###########################################
FOUND_BOOTNODE=false
while sleep 5; do
	for i in `seq 0 $(($NUM_BOOT_NODES - 1))`; do
		if [ "`hostname`" == "${BOOTNODES[$i]}" ]; then
			continue
		fi

		LOOKUP=`nslookup "${BOOTNODES[$i]}" | grep "can't find"`
		if [ "$LOOKUP" == "" ]; then
			FOUND_BOOTNODE=true
			break
		fi
	done

	if [ "$FOUND_BOOTNODE" == "true" ]; then
		break
	fi
done

#####################################################
# Replace hostnames in config file with IP addresses
#####################################################
BOOTNODE_URLS=`echo $BOOTNODE_URLS | perl -pe 's/#(.*?)#/qx\/nslookup $1| egrep "Address: [0-9]"| cut -d" " -f2 | xargs echo -n\//ge'`
echo "bootnode_urls are: ${BOOTNODE_URLS}"

ETHERADMIN_LOG_FILE_PATH="$HOMEDIR/etheradmin.log";

# Get IP address for geth RPC binding
IPADDR=`hostname -i`;

# Only mine on mining nodes
if [ $NODE_TYPE -ne 0 ]; then
  MINE_OPTIONS="--mine --minerthreads $MINER_THREADS";
else
  FAST_SYNC="--fast";
fi

VERBOSITY=4;

echo "===== Starting geth node =====";
set -x;
nohup geth --datadir $GETH_HOME -verbosity $VERBOSITY $BOOTNODE_URLS --maxpeers $MAX_PEERS --nat none --networkid $NETWORK_ID --identity $IDENTITY $MINE_OPTIONS $FAST_SYNC --rpc --rpcaddr "$IPADDR" --rpccorsdomain "*" >> $GETH_LOG_FILE_PATH 2>&1 &
if [ $? -ne 0 ]; then echo "Previous command failed. Exiting"; exit $?; fi
set +x;
echo "===== Started geth node =====";

# Startup admin site on TX VMs
if [ $NODE_TYPE -eq 0 ]; then
  cd $ETHERADMIN_HOME;
  echo "===== Starting admin webserver =====";
  nohup nodejs app.js $ADMIN_SITE_PORT $GETH_HOME/geth.ipc $PREFUND_ADDRESS $PASSWD $CONSORTIUM_MEMBER_ID $endpointurl $masterkey $dbname $collname >> $ETHERADMIN_LOG_FILE_PATH 2>&1 &
  if [ $? -ne 0 ]; then echo "Previous command failed. Exiting"; exit $?; fi
  echo "===== Started admin webserver =====";
fi
echo "===== Completed $0 =====";

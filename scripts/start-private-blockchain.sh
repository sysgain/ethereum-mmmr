#!/bin/bash

#############
# Parameters
#############
if [ $# -lt 2 ]; then echo "Incomplete parameters supplied. usage: \"$0 <config file path> <ethereum account passwd>\""; exit 1; fi
GETH_CFG=$1;
PASSWD=$2;
IP_TO_PING=$3;

########################
# Load config variables
########################
if [ ! -e $GETH_CFG ]; then echo "Config file not found. Exiting"; exit 1; fi
. $GETH_CFG

#############
# Constants
#############
ETHERADMIN_LOG_FILE_PATH="$HOMEDIR/etheradmin.log";
# Log level of geth
VERBOSITY=4;

echo "bootnodes are: $BOOTNODES"
declare -a BOOTNODES

###########################################
# Ensure that at least one bootnode is up
# If not, wait 5 seconds then retry
###########################################
FOUND_BOOTNODE=false
while sleep 5; do
	for i in `seq 0 $(($NUM_BOOT_NODES - 1))`; do
		if [ `hostname` = "${BOOTNODES[$i]}" ]; then
			continue
		fi

		LOOKUP=`nslookup "${BOOTNODES[$i]}" | grep "can't find"`
		if [ -z $LOOKUP ]; then
			FOUND_BOOTNODE=true
			break
		fi
	done

	if [ "$FOUND_BOOTNODE" = true ]; then
		break
	fi
done

#####################################################
# Replace hostnames in config file with IP addresses
#####################################################
BOOTNODE_URLS=`echo $BOOTNODE_URLS | perl -pe 's/#(.*?)#/qx\/nslookup $1| egrep "Address: [0-9]"| cut -d" " -f2 | xargs echo -n\//ge'`
echo "bootnode_urls are: $BOOTNODE_URLS"
############################################################
# Make boot node urls available to other consortium members
############################################################
bootnode_urls_data="{\"id\":\"rbnodes\",\"remoteBootNodeUrls\":\"${BOOTNODE_URLS}\"}"
if [ $NODE_TYPE -eq 0 ]; then
  sh getpost-utility.sh $masterkey "${endpointurl}dbs/${dbname}/colls/${collname}/docs" "post" "$bootnode_urls_data"
fi

######################################
# Get IP address for geth RPC binding
######################################
IPADDR=`hostname -i`;

############################
# Only mine on mining nodes
############################
if [ $NODE_TYPE -ne 0 ]; then
  MINE_OPTIONS="--mine --minerthreads $MINER_THREADS";
else
  FAST_SYNC="--fast";
fi

##########################################
# Startup admin site if this is a TX Node
##########################################
if [ $NODE_TYPE -eq 0 ]; then
  cd $ETHERADMIN_HOME;
  echo "===== Starting admin webserver =====";
  nohup nodejs app.js $ADMIN_SITE_PORT $GETH_HOME/geth.ipc $PREFUND_ADDRESS $PASSWD $CONSORTIUM_MEMBER_ID $endpointurl $masterkey $dbname $collname >> $ETHERADMIN_LOG_FILE_PATH 2>&1 &
  if [ $? -ne 0 ]; then echo "Previous command failed. Exiting"; exit $?; fi
  echo "===== Started admin webserver =====";
fi
echo "===== Completed $0 =====";


############
# Spin until connection has been established
############
while [ ${#IP_TO_PING} -gt 0 ]
do
	ping -c 1 $IP_TO_PING > /dev/null

	if [ $? -eq 0 ]
	then
		echo "connection established"
		break
	fi

	sleep 60
done

##################
# Start geth node
##################
echo "===== Starting geth node =====";
set -x;
nohup geth --datadir $GETH_HOME -verbosity $VERBOSITY $BOOTNODE_URLS --maxpeers $MAX_PEERS --nat none --networkid $NETWORK_ID --identity $IDENTITY $MINE_OPTIONS $FAST_SYNC --rpc --rpcaddr "$IPADDR" --rpccorsdomain "*" >> $GETH_LOG_FILE_PATH 2>&1 &
if [ $? -ne 0 ]; then echo "Previous command failed. Exiting"; exit $?; fi
set +x;
echo "===== Started geth node =====";
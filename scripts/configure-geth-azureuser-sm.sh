#!/bin/bash
#load all the Utility functions 
. deployment-utility.sh
echo "===== Initializing geth installation =====";
date;
# Utility function to exit with message
unsuccessful_exit()
{
  echo "FATAL: Exiting script due to: $1";
  exit 1;
}

echo "===== Initializing geth installation =====";
date;

############
# Parameters
############
# Validate that all arguments are supplied
if [ $# -lt 19 ]; then unsuccessful_exit "Insufficient parameters supplied."; fi

AZUREUSER=$1;
PASSWD=$2;
PASSPHRASE=$3;
ARTIFACTS_URL_PREFIX=$4;
NETWORK_ID=$5;
MAX_PEERS=$6;
NODE_TYPE=$7;       # (0=Transaction node; 1=Mining node )
GETH_IPC_PORT=$8;
NUM_BOOT_NODES=$9;
NUM_MN_NODES=${10};
MN_NODE_PREFIX=${11};
MN_NODE_SEQNUM=${12};   #Only supplied for NODE_TYPE=1
NUM_TX_NODES=${12};     #Only supplied for NODE_TYPE=0
TX_NODE_PREFIX=${13};   #Only supplied for NODE_TYPE=0
ADMIN_SITE_PORT=${14};  #Only supplied for NODE_TYPE=0
PRIMARY_KEY=${15}
DOCDB_END_POINT_URL=${16}
REGIONID=${17}
PEERINFODB=${18}
PEERINFOCOLL=${19}
SLEEPTIME=${20}
EXPIRYTIME=${21}
#########################################################################
# Globals
#########################################################################
declare NODE_KEY
PREFUND_ADDRESS=""
declare -a BOOTNODES
declare -a BOOTNODE_URLS="";

#########################################################################
# Constants
##########################################################################
MINER_THREADS=1;
# Difficulty constant represents ~15 sec. block generation for one node
DIFFICULTY_CONSTANT="0x3333";

HOMEDIR="/home/$AZUREUSER";
VMNAME=`hostname`;
GETH_HOME="$HOMEDIR/.ethereum";
mkdir -p $GETH_HOME;
ETHERADMIN_HOME="$HOMEDIR/etheradmin";
GETH_LOG_FILE_PATH="$HOMEDIR/geth.log";
GENESIS_FILE_PATH="$HOMEDIR/genesis.json";
GETH_CFG_FILE_PATH="$HOMEDIR/geth.cfg";
NODEKEY_FILE_PATH="$GETH_HOME/nodekey";
hostname=`hostname`
ipaddress=`hostname -i`
consortiumid=1
regionid=$REGIONID
masterkey=$PRIMARY_KEY
endpointurl=$DOCDB_END_POINT_URL
dbname=$PEERINFODB
collname=$PEERINFOCOLL
sleeptime=$SLEEPTIME
expirytime=$EXPIRYTIME
##############################
# Scale difficulty
##############################
# Target difficulty scales with number of miners
DIFFICULTY=`printf "0x%X" $(($DIFFICULTY_CONSTANT * $NUM_MN_NODES))`;
cd $HOMEDIR;
setup_dependencies
sleep 180
setup_node_info
setup_bootnodes
echo "BootNode URLs are:${BOOTNODE_URLS[*]}"
setup_genesis_file_system_ethereum_account
initialize_geth
setup_admin_website
create_config
setup_rc_local

########################
# Start geth
########################
echo "===== Starting private blockchain network =====";
/bin/bash $HOMEDIR/start-private-blockchain-sm.sh $GETH_CFG_FILE_PATH $PASSWD || unsuccessful_exit "failed while running start-private-blockchain-sm.sh";
echo "===== Started private blockchain network successfully =====";
echo "===== All commands in ${0} succeeded. Exiting. =====";
exit 0;

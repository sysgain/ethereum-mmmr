#!/bin/bash
. deployment-utility.sh
echo "===== Initializing geth installation =====";
date;

############
# Parameters
############
# Validate that all arguments are supplied
if [ $# -lt 15 ]; then echo "Insufficient parameters supplied. Exiting"; exit 1; fi

AZUREUSER=$1;
PASSWD=$2;
PASSPHRASE=$3;
ARTIFACTS_URL_PREFIX=$4;
CONSORTIUM_DATA_ROOT=${21};
MAX_PEERS=$6;
NODE_TYPE=$7;               # (0=Transaction node; 1=Mining node )
GETH_IPC_PORT=$8;
NUM_BOOT_NODES=$9;
NUM_MN_NODES=${10};
MN_NODE_PREFIX=${11};
MN_NODE_SEQNUM=${14};       #Only supplied for NODE_TYPE=1
NUM_TX_NODES=${14};         #Only supplied for NODE_TYPE=0
TX_NODE_PREFIX=${15};       #Only supplied for NODE_TYPE=0
ADMIN_SITE_PORT=${16};      #Only supplied for NODE_TYPE=0
CONSORTIUM_MEMBER_ID=${17}; #Only supplied for NODE_TYPE=0
PRIMARY_KEY=${18};
DOCDB_END_POINT_URL=${19};
REGIONID=${20};
PEERINFODB=${22};
PEERINFOCOLL=${23};
REMOTE_DOCDB_END_POINT_URL=${24};
REMOTE_DOCDB_PRIMARY_KEY=${25};
REMOTE_PEERINFODB=${26};
REMOTE_PEERINFOCOLL=${27};
DEPLOYMENT_MODE=${28}
sleeptime=${29}
expirytime=${30}
#############
# Globals
#############
declare -a NODE_KEYS
PREFUND_ADDRESS=""
BOOTNODE_URLS="";
declare -a BOOTNODES
declare -a RNODES
remotedbname="";
remotecollname="";
remoteendpointurl="";
remotedocdbprimarykey="";
#############
# Constants
#############
MINER_THREADS=1;
HOMEDIR="/home/$AZUREUSER";
VMNAME=`hostname`;
GETH_HOME="$HOMEDIR/.ethereum";
mkdir -p $GETH_HOME;
ETHERADMIN_HOME="$HOMEDIR/etheradmin";
GETH_LOG_FILE_PATH="$HOMEDIR/geth.log";
GENESIS_FILE_PATH="$HOMEDIR/genesis.json";
GETH_CFG_FILE_PATH="$HOMEDIR/geth.cfg";
NODEKEY_SHARE_PATH="$GETH_HOME/nodekey";
#BOOTNODE_SHARE_PATH="$ETHERADMIN_HOME/public/bootnodes.txt"
NETWORKID_SHARE_PATH="$ETHERADMIN_HOME/public/networkid.txt"
REMOTE_GENESIS_BLOCK_URL="$CONSORTIUM_DATA_ROOT/genesis.json";
REMOTE_NETWORK_ID_URL="$CONSORTIUM_DATA_ROOT/networkid.txt";
hostname=`hostname`;
ipaddress=`hostname -i`;
consortiumid=$CONSORTIUM_MEMBER_ID;
regionid=$REGIONID;
masterkey=$PRIMARY_KEY;
endpointurl=$DOCDB_END_POINT_URL;
dbname=$PEERINFODB;
collname=$PEERINFOCOLL;
# Below information will be loaded from another consortium member
mode=$DEPLOYMENT_MODE
nodecount=`expr $NUM_MN_NODES + $NUM_TX_NODES`
echo "node_count is: $nodecount"
echo "mode is: $mode"
cd $HOMEDIR;
setup_dependencies
#if the deployment mode is Single or Leader remote bootnodes are refered from the same document db 
if [ "$mode" == "Single" -o "$mode" == "Leader" ]
then
remotedbname=$PEERINFODB;
remotecollname=$PEERINFOCOLL;
remoteendpointurl=$DOCDB_END_POINT_URL;
remotedocdbprimarykey=$PRIMARY_KEY;
else
remotedbname=$REMOTE_PEERINFODB;
remotecollname=$REMOTE_PEERINFOCOLL;
remoteendpointurl=$REMOTE_DOCDB_END_POINT_URL;
remotedocdbprimarykey=$REMOTE_DOCDB_PRIMARY_KEY;
fi
echo "remotedbname=${remotedbname}"
echo "remotecollname=${remotecollname}"
echo "remoteendpointurl=${remoteendpointurl}"
echo "remotepkey=$remotedocdbprimarykey"
cd $HOMEDIR;
hostcount=0
allremotedocs=""
while sleep 5; do
        allremotedocs=`sh getpost-utility.sh $remotedocdbprimarykey "${remoteendpointurl}dbs/${remotedbname}/colls/${remotecollname}/docs" get`
        echo "allRemotedocs: $allremotedocs"
        hostcount=`echo $allremotedocs | grep -Po '"bootNodeUrlNode":.*?",' | cut -d "," -f1 | cut -d '"' -f4 | wc -l`
        if [ $hostcount -gt $NUM_MN_NODES ]; then
           break
        fi
done
#RNODES=`echo $allremotedocs | grep -Po '"remoteBootNodeUrls":.*?",' | cut -d "," -f1 | cut -d '"' -f4`
echo "hostcount=$hostcount"
for var in `seq 0 $(($hostcount - 1 ))`; do
RNODES[$var]=`echo $allremotedocs | grep -Po '"bootNodeUrlNode":.*?",' | cut -d "," -f1 | cut -d '"' -f4 | sed -n "$(( $var + 1 ))p"`
done
echo "RNodes: ${RNODES[*]}"
        count=0
        for var in `seq 0 $(($hostcount - 1 ))`; do
                rbnurl=`echo ${RNODES[$var]} | grep "mn.*$reg1.*"`
                echo "rbnurl:$rbnurl"
                if [ -z $rbnurl ]; then
                        continue
                else
                        
                        REMOTE_BOOTNODE_URL_TEMP[$count]=$rbnurl
                        count=$(( $count + 1 ))
                        if [ $count -eq 2 ]; then
                         break
                        fi

                fi
        done
for var in `seq 0 1`; do
REMOTE_BOOTNODE_URL[$var]=`echo ${REMOTE_BOOTNODE_URL_TEMP[$var]} | cut -d "#" -f1,3 | tr -d "#"`
done
REMOTE_BOOTNODE_URLS=`echo "${REMOTE_BOOTNODE_URL[*]}"`
echo "CONSORTIUM_DATA_ROOT = "$CONSORTIUM_DATA_ROOT;

setup_node_info
setup_bootnodes
echo "Boot Node urls:${BOOTNODE_URLS[*]}"
BOOTNODE_URLS=`echo "${BOOTNODE_URLS[*]}"`
echo "bootnode urls:${BOOTNODE_URLS}"
echo "Remote bootnode urls:${REMOTE_BOOTNODE_URLS}"
#########################################
# Download Boot Node Urls of other member and get IP to 
# append to bootnodes.txt
#########################################
#wget -N ${REMOTE_BOOTNODE_URL} || exit 1;
IP_TO_PING=`echo "${REMOTE_BOOTNODE_URLS}" | grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}' | head -1`
echo "IP_TO_PING is: $IP_TO_PING"
#REMOTE_BOOTNODE_URLS=`cat bootnodes.txt`;
BOOTNODE_URLS="$BOOTNODE_URLS $REMOTE_BOOTNODE_URLS";
echo "Total Boot Nodes: $BOOTNODE_URLS"
#########################################
# Setup ethereum account for the system
#########################################
setup_system_ethereum_account

##################################
# Download the genesis block file
##################################
cd $HOMEDIR;
sudo /bin/bash -c "wget -N ${REMOTE_GENESIS_BLOCK_URL}";

##################################
# Download and read the NetworkId
##################################
wget -N ${REMOTE_NETWORK_ID_URL} || exit 140;
NETWORK_ID=`cat networkid.txt`;

initialize_geth
setup_admin_website
create_config
setup_rc_local

############
# Start geth
############
cd $HOMEDIR;
wget -N ${ARTIFACTS_URL_PREFIX}/scripts/start-private-blockchain.sh || exit 1;
nohup /bin/bash $HOMEDIR/start-private-blockchain.sh $GETH_CFG_FILE_PATH $PASSWD $IP_TO_PING &
echo "Commands succeeded. Exiting";
exit 0;

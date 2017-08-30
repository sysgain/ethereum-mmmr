#!/bin/bash

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
if [ $# -lt 10 ]; then unsuccessful_exit "Insufficient parameters supplied."; fi

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
#CONSORTIUM_MEMBER_ID=${17};         #Only supplied for NODE_TYPE=0
PRIMARY_KEY=${15}
DOCDB_END_POINT_URL=${16}
REGIONID=${17}
PEERINFODB=${18}
PEERINFOCOLL=${19}
#########################################################################
# Globals
#########################################################################
declare -a NODE_KEYS
PREFUND_ADDRESS=""
BOOTNODE_URLS="";

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
collname=$PEERINFOCOL
##################
# Scale difficulty
##################
# Target difficulty scales with number of miners
DIFFICULTY=`printf "0x%X" $(($DIFFICULTY_CONSTANT * $NUM_MN_NODES))`;

################
# Update modules
################
echo "===== Starting packages update =====";
sudo apt-get -y update || exit 1;
echo "===== Completed packages update =====";
# To avoid intermittent issues with package DB staying locked when next apt-get runs
sleep 5;

##################
# Install packages
##################
echo "===== Starting packages installation =====";
sudo apt-get -y install npm=3.5.2-0ubuntu4 git=1:2.7.4-0ubuntu1 || unsuccessful_exit "package install 1 failed";
sudo update-alternatives --install /usr/bin/node nodejs /usr/bin/nodejs 100 || unsuccessful_exit "package install 2 failed";
echo "===== Completed packages installation =====";

##############
# Install geth
##############
echo "===== Starting geth installation =====";
wget https://gethstore.blob.core.windows.net/builds/geth-alltools-linux-amd64-1.6.0-facc47cb.tar.gz || unsuccessful_exit "geth download failed";
wget https://gethstore.blob.core.windows.net/builds/geth-alltools-linux-amd64-1.6.0-facc47cb.tar.gz.asc || unsuccessful_exit "geth signature download failed";

# Import geth buildserver keys
gpg --recv-keys --keyserver hkp://keys.gnupg.net F9585DE6 C2FF8BBF 9BA28146 7B9E2481 D2A67EAC || unsuccessful_exit "import geth buildserver keys failed";

# Validate signature
gpg --verify geth-alltools-linux-amd64-1.6.0-facc47cb.tar.gz.asc || unsuccessful_exit "validate geth download failed";

# Unpack archive
tar xzf geth-alltools-linux-amd64-1.6.0-facc47cb.tar.gz || unsuccessful_exit "geth download unpack failed";

# /usr/bin is in $PATH by default, we'll put our binaries there
sudo cp geth-alltools-linux-amd64-1.6.0-facc47cb/* /usr/bin/ || unsuccessful_exit "copy of geth to /usr/bin failed";
echo "===== Completed geth installation =====";
#############
# Build boot nodes from geristrar 
#############
echo "masterkey:$masterkey"
echo "endpointurl:$endpointurl"
getalldbs=`sh getpost-utility.sh $masterkey "${endpointurl}dbs" get`
dbcount=`echo $getalldbs | grep "\"id\":.*"`
docdata="{\"id\":\"${hostname}\",\"hostname\": \"${hostname}\",\"ipaddress\": \"${ipaddress}\",\"consortiumID\": \"${consortiumid}\",\"regionId\": \"${regionid}\"}"
dbdata="{\"id\":\"${dbname}\"}"
colldata="{\"id\":\"${collname}\"}"
#check wheather database exists if not create  database
if [ "$dbcount" == "" ]
then
 `sh getpost-utility.sh $masterkey "${endpointurl}dbs" "post" "$dbdata"`
 echo ".........\"${dbname}\" database got created......... "
else
 echo "database already present"
fi
getalldbs=`sh getpost-utility.sh $masterkey "${endpointurl}dbs" get`
echo "Database details are: $getalldbs"

#check wheather collection  exists if not create testcolls collection
getallcolls=`sh getpost-utility.sh $masterkey "${endpointurl}dbs/${dbname}/colls" get`
collscount=`echo $getallcolls | grep "\"id\":.*"`
if [ "$collscount" == "" ]
then
`sh getpost-utility.sh $masterkey "${endpointurl}dbs/${dbname}/colls" "post" "$colldata"`
 echo ".........\"testcolls\" collection got created......... "
else
echo "collection  already present"
fi
getallcolls=`sh getpost-utility.sh $masterkey "${endpointurl}dbs/${dbname}/colls" get`
echo "Collection details are: $getallcolls"
#create a document in database with the current node info
sh getpost-utility.sh $masterkey "${endpointurl}dbs/${dbname}/${collname}/docs" "post" "$docdata"

#wait for at least 2 nodes to comeup
while sleep 5; do
        alldocs=`sh getpost-utility.sh $masterkey "${endpointurl}dbs/${dbname}/colls/${collname}/docs" get`
        hostcount=`echo $alldocs | grep -Po '"hostname":.*?",' |cut -d "," -f1 | cut -d ":" -f2 |wc -l`
        if [ $hostcount -gt 2 ]; then
                break
        fi
done

#finding all the hostnames and storing it in an array
for var in `seq 0 $(($hostcount - 1 ))`; do
NODES[$var]=`echo $alldocs | grep -Po '"hostname":.*?",' |sed -n "$(($var + 1 ))p" | cut -d "," -f1 | cut -d ":" -f2`
done
echo "Nodes: ${NODES[*]}"

#finding all the IP addresses and storing it in an array
for varip in `seq 0 $(($hostcount - 1 ))`; do
IPS[$varip]=`echo $alldocs | grep -Po '"ipaddress":.*?",' |sed -n "$(($varip + 1 ))p" | cut -d "," -f1 | cut -d ":" -f2`
done
echo "IP Addresses: ${IPS[*]}"

#finding atleast 2 bootnodes
count=0
for var in `seq 0 $(($hostcount - 1 ))`; do
        reg=`echo ${NODES[$var]} | grep "$regionid"`
        if [ -z $reg ]; then
            continue
        else
            BOOTNODESREGONE[$count]=$reg
            count=$(($count + 1 ))
            if [ $count -eq 2 ]; then
                break
            fi

        fi
done

BOOTNODES=( "${BOOTNODESREGONE[@]}" )
echo "BootNodes: ${BOOTNODES[*]}"
NUM_BOOT_NODES=`echo ${#BOOTNODESREGONE[*]}`
echo "Num of Bootnodes is: $NUM_BOOT_NODES"

#############
# Build node keys and node IDs
#############
echo "===== Starting node key and node ID generation =====";
declare -a NODE_KEYS
declare -a NODE_IDS
for i in `seq 0 $(($NUM_BOOT_NODES - 1))`; do
	BOOT_NODE_HOSTNAME=$BOOTNODES[$i];
	NODE_KEYS[$i]=`echo $BOOT_NODE_HOSTNAME | sha256sum | cut -d ' ' -f 1`;
	setsid geth -nodekeyhex ${NODE_KEYS[$i]} > $HOMEDIR/tempbootnodeoutput 2>&1 &
	while sleep 10; do
		if [ -s $HOMEDIR/tempbootnodeoutput ]; then
			killall geth || unsuccessful_exit "failed to kill all geth processes";
			NODE_IDS[$i]=`grep -Po '(?<=\/\/).*(?=@)' $HOMEDIR/tempbootnodeoutput`;
			rm $HOMEDIR/tempbootnodeoutput || unsuccessful_exit "failed to remove tempbootnodeoutput file";
			break;
		fi
	done
done

##################################
# Check for empty node keys or IDs
##################################
for nodekey in "${NODE_KEYS[@]}"; do
	if [ -z $nodekey ]; then
		unsuccessful_exit "empty node key detected";
	fi
done
for nodeid in "${NODE_IDS[@]}"; do
	if [ -z $nodeid ]; then
		unsuccessful_exit "empty node ID detected";
	fi
done

echo "===== Completed node key and node ID generation =====";

##############################################
# Setup Genesis file and pre-allocated account
##############################################
echo "===== Starting genesis file and pre-allocated account creation =====";
PASSWD_FILE="$GETH_HOME/passwd.info";
printf %s $PASSWD > $PASSWD_FILE;

PRIV_KEY=`echo "$PASSPHRASE" | sha256sum | sed s/-// | sed "s/ //"`;
printf "%s" $PRIV_KEY > $HOMEDIR/priv_genesis.key;
PREFUND_ADDRESS=`geth --datadir $GETH_HOME --password $PASSWD_FILE account import $HOMEDIR/priv_genesis.key | grep -oP '\{\K[^}]+'` || unsuccessful_exit "failed to import pre-fund account";
if [ -z $PREFUND_ADDRESS ]; then unsuccessful_exit "could not determine address of pre-fund account after importing into geth"; fi
rm $HOMEDIR/priv_genesis.key;
rm $PASSWD_FILE;

cd $HOMEDIR
wget -N ${ARTIFACTS_URL_PREFIX}/scripts/start-private-blockchain-sm.sh || unsuccessful_exit "failed to download start-private-blockchain-sm.sh";
wget -N ${ARTIFACTS_URL_PREFIX}/genesis-template.json || unsuccessful_exit "failed to download genesis-template.json";
# Place our calculated difficulty into genesis file
sed s/#DIFFICULTY/$DIFFICULTY/ $HOMEDIR/genesis-template.json > $HOMEDIR/genesis-intermediate1.json;
sed s/#PREFUND_ADDRESS/$PREFUND_ADDRESS/ $HOMEDIR/genesis-intermediate1.json > $HOMEDIR/genesis-intermediate2.json;
sed s/#NETWORKID/$NETWORK_ID/ $HOMEDIR/genesis-intermediate2.json > $HOMEDIR/genesis.json;

echo "===== Completed genesis file and pre-allocated account creation =====";

####################
# Initialize geth for private network
####################
echo "===== Starting initialization of geth for private network =====";
if [ $NODE_TYPE -eq 1 ] && [ $MN_NODE_SEQNUM -lt $NUM_BOOT_NODES ]; then #Boot node logic
	printf %s ${NODE_KEYS[$MN_NODE_SEQNUM]} > $NODEKEY_FILE_PATH;
fi

#################
# Initialize geth
#################

# Clear out old chaindata
rm -rf $GETH_HOME/geth/chaindata
geth --datadir $GETH_HOME -verbosity 6 init $GENESIS_FILE_PATH >> $GETH_LOG_FILE_PATH 2>&1;
if [ $? -ne 0 ]; then
	unsuccessful_exit "geth initialization failed";
fi
echo "===== Completed initialization of geth for private network =====";

#####################
# Setup admin website
#####################
if [ $NODE_TYPE -eq 0 ]; then # TX nodes only
	echo "===== Starting admin website setup =====";
	mkdir -p $ETHERADMIN_HOME/views/layouts;
	cd $ETHERADMIN_HOME/views/layouts;
	wget -N ${ARTIFACTS_URL_PREFIX}/scripts/etheradmin/main.handlebars || unsuccessful_exit "failed to download main.handlebars";
	cd $ETHERADMIN_HOME/views;
	wget -N ${ARTIFACTS_URL_PREFIX}/scripts/etheradmin/etheradmin.handlebars || unsuccessful_exit "failed to download etheradmin.handlebars";
	wget -N ${ARTIFACTS_URL_PREFIX}/scripts/etheradmin/etherstartup.handlebars || unsuccessful_exit "failed to download etherstartup.handlebars";
	cd $ETHERADMIN_HOME;
	wget -N ${ARTIFACTS_URL_PREFIX}/scripts/etheradmin/package.json || unsuccessful_exit "failed to download package.json";
	wget -N ${ARTIFACTS_URL_PREFIX}/scripts/etheradmin/npm-shrinkwrap.json || unsuccessful_exit "failed to download npm-shrinkwrap.json";
	npm install || unsuccessful_exit "failed while running npm install";
	wget -N ${ARTIFACTS_URL_PREFIX}/scripts/etheradmin/app.js || unsuccessful_exit "failed to download app.js";
	mkdir $ETHERADMIN_HOME/public;
	cd $ETHERADMIN_HOME/public;
	wget -N ${ARTIFACTS_URL_PREFIX}/scripts/etheradmin/skeleton.css || unsuccessful_exit "failed to download skeleton.css";
	echo "===== Completed admin website setup =====";
fi

#########################
# Generate boot node URLs
####################
echo "===== Starting bootnode URL generation =====";
for i in `seq 0 $(($NUM_BOOT_NODES - 1))`; do
	BOOTNODE_URLS="${BOOTNODE_URLS}enode://${NODE_IDS[$i]}@#${BOOTNODES[$i]}#:${GETH_IPC_PORT}";
  if [ $i -lt $(($NUM_BOOT_NODES - 1)) ]; then
  	BOOTNODE_URLS="${BOOTNODE_URLS} --bootnodes ";
  fi
done
echo "===== Completed bootnode URL generation =====";

##################
# Create conf file
##################
printf "%s\n" "HOMEDIR=$HOMEDIR" > $GETH_CFG_FILE_PATH;
printf "%s\n" "IDENTITY=$VMNAME" >> $GETH_CFG_FILE_PATH;
printf "%s\n" "NETWORK_ID=$NETWORK_ID" >> $GETH_CFG_FILE_PATH;
printf "%s\n" "MAX_PEERS=$MAX_PEERS" >> $GETH_CFG_FILE_PATH;
printf "%s\n" "NODE_TYPE=$NODE_TYPE" >> $GETH_CFG_FILE_PATH;
printf "%s\n" "BOOTNODE_URLS=$BOOTNODE_URLS" >> $GETH_CFG_FILE_PATH;
printf "%s\n" "MN_NODE_PREFIX=$MN_NODE_PREFIX" >> $GETH_CFG_FILE_PATH;
printf "%s\n" "NUM_BOOT_NODES=$NUM_BOOT_NODES" >> $GETH_CFG_FILE_PATH;
printf "%s\n" "MINER_THREADS=$MINER_THREADS" >> $GETH_CFG_FILE_PATH;
printf "%s\n" "GETH_HOME=$GETH_HOME" >> $GETH_CFG_FILE_PATH;
printf "%s\n" "GETH_LOG_FILE_PATH=$GETH_LOG_FILE_PATH" >> $GETH_CFG_FILE_PATH;

if [ $NODE_TYPE -eq 0 ]; then #TX node
  printf "%s\n" "ETHERADMIN_HOME=$ETHERADMIN_HOME" >> $GETH_CFG_FILE_PATH;
  printf "%s\n" "PREFUND_ADDRESS=$PREFUND_ADDRESS" >> $GETH_CFG_FILE_PATH;
  printf "%s\n" "NUM_MN_NODES=$NUM_MN_NODES" >> $GETH_CFG_FILE_PATH;
  printf "%s\n" "TX_NODE_PREFIX=$TX_NODE_PREFIX" >> $GETH_CFG_FILE_PATH;
  printf "%s\n" "NUM_TX_NODES=$NUM_TX_NODES" >> $GETH_CFG_FILE_PATH;
  printf "%s\n" "ADMIN_SITE_PORT=$ADMIN_SITE_PORT" >> $GETH_CFG_FILE_PATH;
fi

##########################################
# Setup rc.local for service start on boot
##########################################
echo "===== Setting up rc.local for restart on VM reboot =====";
echo -e '#!/bin/bash' "\nsudo -u $AZUREUSER /bin/bash $HOMEDIR/start-private-blockchain-sm.sh $GETH_CFG_FILE_PATH $PASSWD" | sudo tee /etc/rc.local 2>&1 1>/dev/null
if [ $? -ne 0 ]; then
	unsuccessful_exit "failed to setup rc.local for restart on VM reboot";
fi
echo "===== Completed setting up rc.local for restart on VM reboot =====";

############
# Start geth
############
echo "===== Starting private blockchain network =====";
/bin/bash $HOMEDIR/start-private-blockchain-sm.sh $GETH_CFG_FILE_PATH $PASSWD || unsuccessful_exit "failed while running start-private-blockchain-sm.sh";
echo "===== Started private blockchain network successfully =====";

echo "===== All commands in ${0} succeeded. Exiting. =====";
exit 0;

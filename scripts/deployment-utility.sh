function setup_dependencies
{
        ################
        # Update modules
        ################
        sudo apt-get -y update || exit 1;
        # To avoid intermittent issues with package DB staying locked when next apt-get runs
        sleep 5;

        ##################
        # Install packages
        ##################
        sudo apt-get -y install npm=3.5.2-0ubuntu4 git=1:2.7.4-0ubuntu1 software-properties-common  -y --allow-downgrades || exit 1;
        sudo update-alternatives --install /usr/bin/node nodejs /usr/bin/nodejs 100 || exit 1;

        ##############
        # Install geth
        ##############
        wget https://gethstore.blob.core.windows.net/builds/geth-alltools-linux-amd64-1.5.9-a07539fb.tar.gz || exit 1;
        wget https://gethstore.blob.core.windows.net/builds/geth-alltools-linux-amd64-1.5.9-a07539fb.tar.gz.asc || exit 1;
         # Import geth buildserver keys
        gpg --recv-keys --keyserver hkp://keys.gnupg.net F9585DE6 C2FF8BBF 9BA28146 7B9E2481 D2A67EAC || exit 1;

        # Validate signature
        gpg --verify geth-alltools-linux-amd64-1.5.9-a07539fb.tar.gz.asc || exit 1;

        # Unpack archive
        tar xzf geth-alltools-linux-amd64-1.5.9-a07539fb.tar.gz || exit 1;

        # /usr/bin is in $PATH by default, we'll put our binaries there
        sudo cp geth-alltools-linux-amd64-1.5.9-a07539fb/* /usr/bin/ || exit 1;
}
function update
{
        timestamp=`date +%s`
        if [ $NODE_TYPE -eq 1 ];then
        docdata="{\"id\":\"${hostname}\",\"hostname\": \"${hostname}\",\"ipaddress\": \"${ipaddress}\",\"consortiumID\": \"NA\",\"regionId\": \"${regionid}\",\"bootNodeUrl\": \"null\"}"
        else
        docdata="{\"id\":\"${hostname}\",\"hostname\": \"${hostname}\",\"ipaddress\": \"${ipaddress}\",\"consortiumID\": \"${consortiumid}\",\"regionId\": \"${regionid}\",\"bootNodeUrl\": \"null\"}"
        fi
        while sleep $sleeptime; do
        sh getpost-utility.sh $masterkey "${endpointurl}dbs/${dbname}/colls/${collname}/docs/${hostname}" "put" "$docdata"
        done
}

function setup_bootnodes
{
echo "masterkey:$masterkey"
echo "endpointurl:$endpointurl"
getalldbs=`sh getpost-utility.sh $masterkey "${endpointurl}dbs" get`
dbcount=`echo $getalldbs | grep "\"id\":.*"`
if [ $NODE_TYPE -eq 1 ];then
docdata="{\"id\":\"${hostname}\",\"hostname\": \"${hostname}\",\"ipaddress\": \"${ipaddress}\",\"consortiumID\": \"NA\",\"regionId\": \"${regionid}\",\"bootNodeUrl\": \"null\"}"
else
docdata="{\"id\":\"${hostname}\",\"hostname\": \"${hostname}\",\"ipaddress\": \"${ipaddress}\",\"consortiumID\": \"${consortiumid}\",\"regionId\": \"${regionid}\",\"bootNodeUrl\": \"null\"}"
fi
dbdata="{\"id\":\"${dbname}\"}"
colldata="{\"id\":\"${collname}\"}"
#check wheather database exists if not create testdb database
if [ "$dbcount" == "" ]
then
 `sh getpost-utility.sh $masterkey "${endpointurl}dbs" "post" "$dbdata"`
 echo ".........\"$dbname\" database got created......... "
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
 echo ".........\"$colldata\" collection got created......... "
else
echo "collection  already present"
fi
getallcolls=`sh getpost-utility.sh $masterkey "${endpointurl}dbs/${dbname}/colls" get`
echo "Collection details are: $getallcolls"
#create a document in database with the current node info
sh getpost-utility.sh $masterkey "${endpointurl}dbs/${dbname}/colls/${collname}/docs" "post" "$docdata"
alldocs=`sh getpost-utility.sh $masterkey "${endpointurl}dbs/${dbname}/colls/${collname}/docs" get`
echo "created the document"
echo "$alldocs"
update &
alldocs=`sh getpost-utility.sh $masterkey "${endpointurl}dbs/${dbname}/colls/${collname}/docs" get`
echo "Document details after Update"
echo "$alldocs"
#wait for at least 2 nodes to comeup
while sleep 5; do
        alldocs=`sh getpost-utility.sh $masterkey "${endpointurl}dbs/${dbname}/colls/${collname}/docs" get`
        hostcount=`echo $alldocs | grep -Po '"hostname":.*?",' |cut -d "," -f1 | cut -d ":" -f2 |wc -l`
        if [ $hostcount -gt 2 ]; then
                break
        fi
done

#finding the available hostnames and storing it in an array
for var in `seq 0 $(($hostcount - 1 ))`; do
TS[$var]=`echo $alldocs | grep -Po '"_ts":.*?",' |sed -n "$(($var + 1 ))p" | cut -d "," -f1 | cut -d ":" -f2`
echo "TimeStamp on present node is: $TS[$var]"
presentTS=`date +%s`
diffTS=`expr $presentTS - $TS[$var]`
if [ "$diffTS" -gt "$expirytime" ]
then
continue
else
NODES[$var]=`echo $alldocs | grep -Po '"hostname":.*?",' |sed -n "$(($var + 1 ))p" | cut -d "," -f1 | cut -d ":" -f2`
fi
done
echo "Nodes: ${NODES[*]}"

#finding the available IP addresses and storing it in an array
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
}

function setup_node_info
{
        declare -a NODE_IDS
        declare -a NODE_KEYS
        timestamp=`date +%s`
        #############
        # Build node keys and node IDs
        #############
        for i in `seq 0 $(($NUM_BOOT_NODES - 1))`; do
                BOOT_NODE_HOSTNAME=$BOOTNODES[$i];
                NODE_KEYS[$i]=`echo $BOOT_NODE_HOSTNAME | sha256sum | cut -d ' ' -f 1`;
                echo "nodekey is:  ${NODE_KEYS[$i]}"
                setsid geth -nodekeyhex ${NODE_KEYS[$i]} > $HOMEDIR/tempbootnodeoutput 2>&1 &
                while sleep 10; do
                 if [ -s $HOMEDIR/tempbootnodeoutput ]; then
                                killall geth;
                                NODE_IDS[$i]=`grep -Po '(?<=\/\/).*(?=@)' $HOMEDIR/tempbootnodeoutput`;
                                rm $HOMEDIR/tempbootnodeoutput;
                                if [ $? -ne 0 ]; then
                                        exit 1;
                                fi
                                break;
                        fi
                done
        done

        ##################################
        # Check for empty node keys or IDs
        ##################################
        for nodekey in "${NODE_KEYS[@]}"; do
                if [ -z $nodekey ]; then
                        exit 1;
                fi
        done
        for nodeid in "${NODE_IDS[@]}"; do
                if [ -z $nodeid ]; then
                        exit 1;
                fi
        done

        ##########################
        # Generate boot node URLs
        ##########################
        for i in `seq 0 $(($NUM_BOOT_NODES - 1))`; do
         BOOTNODE_URLS="${BOOTNODE_URLS} --bootnodes enode://${NODE_IDS[$i]}@#${BOOTNODES[$i]}#:${GETH_IPC_PORT}";
         docdata="{\"id\":\"${BOOTNODES[$i]}${timestamp}\",\"hostname\": \"${BOOTNODES[$i]}\",\"ipaddress\": \"${ipaddress}\",\"consortiumID\": \"${consortiumid}\",\"regionId\": \"${regionid}\",\"bootNodeUrl\": \"${BOOTNODE_URLS}\"}"
         echo "docdata is: $docdata"
         sh getpost-utility.sh $masterkey "${endpointurl}dbs/${dbname}/colls/${collname}/docs/${BOOTNODES[$i]}" "put" "$docdata"
        done
}
function setup_system_ethereum_account
{
	PASSWD_FILE="$GETH_HOME/passwd.info";
	printf %s $PASSWD > $PASSWD_FILE;

	PRIV_KEY=`echo "$PASSPHRASE" | sha256sum | sed s/-// | sed "s/ //"`;
	printf "%s" $PRIV_KEY > $HOMEDIR/priv_genesis.key;
	PREFUND_ADDRESS=`geth --datadir $GETH_HOME --password $PASSWD_FILE account import $HOMEDIR/priv_genesis.key | grep -oP '\{\K[^}]+'`;
	rm $HOMEDIR/priv_genesis.key;
	rm $PASSWD_FILE;
}

function initialize_geth
{
	####################
	# Initialize geth for private network
	####################
	if [ $NODE_TYPE -eq 1 ] && [ $MN_NODE_SEQNUM -lt $NUM_BOOT_NODES ]; then #Boot node logic
		printf %s ${NODE_KEYS[$MN_NODE_SEQNUM]} > $NODEKEY_SHARE_PATH;
	fi

	#################
	# Initialize geth
	#################
	geth --datadir $GETH_HOME -verbosity 6 init $GENESIS_FILE_PATH >> $GETH_LOG_FILE_PATH 2>&1;
	if [ $? -ne 0 ]; then
		exit 1;
	fi
	echo "===== Completed geth initialization =====";
}

function setup_admin_website
{
	POWERSHELL_SHARE_PATH="$ETHERADMIN_HOME/public/ConsortiumBridge.psm1"
	CLI_SHARE_PATH="$ETHERADMIN_HOME/public/ConsortiumBridge.sh"

	#####################
	# Setup admin website
	#####################
	if [ $NODE_TYPE -eq 0 ]; then # TX nodes only
	  mkdir -p $ETHERADMIN_HOME/views/layouts;
	  cd $ETHERADMIN_HOME/views/layouts;
	  wget -N ${ARTIFACTS_URL_PREFIX}/etheradmin/main.handlebars || exit 1;
	  cd $ETHERADMIN_HOME/views;
	  wget -N ${ARTIFACTS_URL_PREFIX}/etheradmin/etheradmin.handlebars || exit 1;
	  wget -N ${ARTIFACTS_URL_PREFIX}/etheradmin/etherstartup.handlebars || exit 1;
	  cd $ETHERADMIN_HOME;
	  wget -N ${ARTIFACTS_URL_PREFIX}/etheradmin/package.json || exit 1;
	  wget -N ${ARTIFACTS_URL_PREFIX}/etheradmin/npm-shrinkwrap.json || exit 1;
	  npm install || exit 1;
	  wget -N ${ARTIFACTS_URL_PREFIX}/etheradmin/app.js || exit 1;
	  mkdir $ETHERADMIN_HOME/public;
	  cd $ETHERADMIN_HOME/public;
	  wget -N ${ARTIFACTS_URL_PREFIX}/etheradmin/skeleton.css || exit 1;

	  # Make consortium data available to joining members
	  cp $GENESIS_FILE_PATH $ETHERADMIN_HOME/public;
	  printf "%s" $NETWORK_ID > $NETWORKID_SHARE_PATH;

	  # Copy the powershell script to admin site
	  wget -N ${ARTIFACTS_URL_PREFIX}/powershell/ConsortiumBridge.psm1 -O ${POWERSHELL_SHARE_PATH} || exit 1;
	  wget -N ${ARTIFACTS_URL_PREFIX}/scripts/ConsortiumBridge.sh -O ${CLI_SHARE_PATH} || exit 1;
	fi
}

function create_config
{
	##################
	# Create conf file
	##################
	printf "%s\n" "HOMEDIR=$HOMEDIR" > $GETH_CFG_FILE_PATH;
	printf "%s\n" "IDENTITY=$VMNAME" >> $GETH_CFG_FILE_PATH;
	printf "%s\n" "NETWORK_ID=$NETWORK_ID" >> $GETH_CFG_FILE_PATH;
	printf "%s\n" "MAX_PEERS=$MAX_PEERS" >> $GETH_CFG_FILE_PATH;
	printf "%s\n" "NODE_TYPE=$NODE_TYPE" >> $GETH_CFG_FILE_PATH;
	printf "%s\n" "BOOTNODE_URLS=\"$BOOTNODE_URLS\"" >> $GETH_CFG_FILE_PATH;
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
          printf "%s\n" "BOOTNODES=${BOOTNODES[*]}" >> $GETH_CFG_FILE_PATH;
          printf "%s\n" "masterkey=$masterkey" >> $GETH_CFG_FILE_PATH;
          printf "%s\n" "endpointurl=$endpointurl" >> $GETH_CFG_FILE_PATH;
          printf "%s\n" "dbname=$dbname" >> $GETH_CFG_FILE_PATH;
          printf "%s\n" "collname=$collname" >> $GETH_CFG_FILE_PATH;
	  #printf "%s\n" "BOOTNODE_SHARE_PATH=$BOOTNODE_SHARE_PATH" >> $GETH_CFG_FILE_PATH;
	  printf "%s\n" "CONSORTIUM_MEMBER_ID=$CONSORTIUM_MEMBER_ID" >> $GETH_CFG_FILE_PATH;
	fi
}

function setup_rc_local
{
	##########################################
	# Setup rc.local for service start on boot
	##########################################
	echo -e '#!/bin/bash' "\nsudo -u $AZUREUSER /bin/bash $HOMEDIR/start-private-blockchain.sh $GETH_CFG_FILE_PATH $PASSWD \"\"" | sudo tee /etc/rc.local 2>&1 1>/dev/null
	if [ $? -ne 0 ]; then
		exit 1;
	fi
}
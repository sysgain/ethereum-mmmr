function setup_dependencies
{
        echo "===== Started  installing prerequisite packages =====";
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
        echo "===== Completed  installing prerequisite packages =====";
}

function setup_node_info
{
        echo "===== Started  Setting up boot node information =====";
        echo "Masterkey:$masterkey"
        echo "Endpointurl:$endpointurl"
        getalldbs=`sh getpost-utility.sh $masterkey "${endpointurl}dbs" get`
        dbcount=`echo $getalldbs | grep "\"id\":.*"`
        dbdata="{\"id\":\"${dbname}\"}"
        colldata="{\"id\":\"${collname}\",\"defaultTtl\": $expirytime}"
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
        timestamp=`date +%s`
        # Build node keys and node IDs
         NODE_HOSTNAME=`echo ${hostname}`;
         echo "Boot Node Host Name is: ${NODE_HOSTNAME}"
         NODE_KEY=`echo $NODE_HOSTNAME | sha256sum | cut -d ' ' -f 1`;
         echo "nodekey is:  ${NODE_KEY}"
         setsid geth -nodekeyhex ${NODE_KEY} > $HOMEDIR/tempbootnodeoutput 2>&1 &
         while sleep 10; do
                if [ -s $HOMEDIR/tempbootnodeoutput ]; then
                                killall geth;
                                NODE_ID=`grep -Po '(?<=\/\/).*(?=@)' $HOMEDIR/tempbootnodeoutput`;
                                rm $HOMEDIR/tempbootnodeoutput;
                                if [ $? -ne 0 ]; then
                                        exit 1;
                                fi
                                break;
                fi
        done
        ##################################
        # Check for empty node keys or IDs
        ##################################
        if [ -z $NODE_KEY ]; then
                exit 1;
        fi
     
        if [ -z $NODE_ID ]; then
                exit 1;
        fi
        
        ##########################
        # Generate boot node URLs
        ##########################
         NODE=`echo ${hostname}`
         #consortium participant ID
         consortiumid=`echo ${NODE} | cut -d "-" -f3 | cut -c5`
         #BOOTNODE_URLS="${BOOTNODE_URLS} --bootnodes enode://${NODE_ID}@#$NODE#:${GETH_IPC_PORT}";
         bootnodeurlpernode=" --bootnodes enode://${NODE_ID}@#$NODE#:${GETH_IPC_PORT}";
         bootnodeurlwithip=" --bootnodes enode://${NODE_ID}@#$NODE#${ipaddress}:${GETH_IPC_PORT}"
         #preparing document details
         if [ $NODE_TYPE -eq 1 ];then
         docdata="{\"id\":\"${NODE}\",\"hostname\": \"${NODE}\",\"ipaddress\": \"${ipaddress}\",\"regionId\": \"${regionid}\",\"consortiumid\": \"${consortiumid}\",\"bootNodeUrlNode\": \"${bootnodeurlwithip}\",\"bootNodeUrl\": \"${bootnodeurlpernode}\"}"
         else
         docdata="{\"id\":\"${NODE}\",\"hostname\": \"${NODE}\",\"ipaddress\": \"${ipaddress}\",\"regionId\": \"${regionid}\",\"consortiumid\": \"NA\",\"bootNodeUrlNode\": \"${bootnodeurlwithip}\",\"bootNodeUrl\": \"${bootnodeurlpernode}\"}"
         fi
         #create a document in database with the current node info
         sh getpost-utility.sh $masterkey "${endpointurl}dbs/${dbname}/colls/${collname}/docs" "post" "$docdata"
         previousuniqid=${NODE}
         while sleep $sleeptime; do
                uniqid=${NODE}${timestamp}
                if [ $NODE_TYPE -eq 1 ];then
                         docdata="{\"id\":\"${uniqid}\",\"hostname\": \"${NODE}\",\"ipaddress\": \"${ipaddress}\",\"regionId\": \"${regionid}\",\"consortiumid\": \"${consortiumid}\",\"bootNodeUrlNode\": \"${bootnodeurlwithip}\",\"bootNodeUrl\": \"${bootnodeurlpernode}\"}"
                 else
                         docdata="{\"id\":\"${uniqid}\",\"hostname\": \"${NODE}\",\"ipaddress\": \"${ipaddress}\",\"regionId\": \"${regionid}\",\"consortiumid\": \"NA\",\"bootNodeUrlNode\": \"${bootnodeurlwithip}\",\"bootNodeUrl\": \"${bootnodeurlpernode}\"}"
                 fi
                 sh getpost-utility.sh $masterkey "${endpointurl}dbs/${dbname}/colls/${collname}/docs/${previousuniqid}" "put" "$docdata"
                 previousuniqid=${uniqid}          
         done &
}

function setup_bootnodes
{
         echo "===== Started  setting up boot nodes =====";
         #wait for at least 5 nodes to comeup
         hostcount=0
         nodecount=`expr $NUM_MN_NODES + 1`
         echo "node_count is: $nodecount"
         while sleep 10; do
                alldocs=`sh getpost-utility.sh $masterkey "${endpointurl}dbs/${dbname}/colls/${collname}/docs" get`
                hostcount=`echo $alldocs | grep -Po '"hostname":.*?",' | cut -d "," -f1 | cut -d ":" -f2 | wc -l`
                if [ $hostcount -ge $nodecount ]; then
                        break
                fi
         done
         #finding the available hostnames and storing it in an array
         alldocs=`sh getpost-utility.sh $masterkey "${endpointurl}dbs/${dbname}/colls/${collname}/docs" get`
         hostcount=`echo $alldocs | grep -Po '"hostname":.*?",' | cut -d "," -f1 | cut -d ":" -f2 | wc -l`
         for var in `seq 0 $(($hostcount - 1 ))`; do
                NODES[$var]=`echo $alldocs | grep -Po '"hostname":.*?",' | sed -n "$(($var + 1 ))p" | cut -d "," -f1 | cut -d ":" -f2 | tr -d "\""`
                NODESURLS[$var]=`echo $alldocs | grep -Po '"bootNodeUrl":.*?",'| cut -d "," -f1 | cut -d '"' -f4 | sed -n "$(($var + 1 ))p"`
         done
         echo "Nodes: ${NODES[*]}"
         echo "Node URLS are: ${NODESURLS[*]}"
         count=0
         for var in `seq 0 $(($hostcount - 1 ))`; do
                reg=`echo ${NODES[$var]} | grep "^mn.*$regionid.*"`
                echo "reg is :$reg"
                bnurl=`echo ${NODESURLS[$var]} | grep "mn.*$regionid.*"`
                echo "bootnodeurl is: $bnurl"
                if [ -z $reg ]; then
                        continue
                else
                        BOOTNODES[$count]=$reg
                        BOOTNODE_URLS[$count]=$bnurl
                        count=$(($count + 1 ))
                        if [ $count -eq 2 ]; then
                         break
                        fi

                fi
         done
         echo "BootNodes: ${BOOTNODES[*]}"
         echo "BOOTNODE_URLS=${BOOTNODE_URLS[*]}"
         echo "===== Completed setting up boot nodes =====";
}

function setup_genesis_file_system_ethereum_account
{
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
}

function initialize_geth
{
        #########################################
        # Initialize geth for private network
        #########################################
        echo "===== Starting initialization of geth for private network =====";
        if [ $NODE_TYPE -eq 1 ] && [ $MN_NODE_SEQNUM -lt $NUM_BOOT_NODES ]; then #Boot node logic
	        printf %s ${NODE_KEY} > $NODEKEY_FILE_PATH;
        fi

        ########################
        # Initialize geth
        ########################

        # Clear out old chaindata
        rm -rf $GETH_HOME/geth/chaindata
        geth --datadir $GETH_HOME -verbosity 6 init $GENESIS_FILE_PATH >> $GETH_LOG_FILE_PATH 2>&1;
        if [ $? -ne 0 ]; then
	        unsuccessful_exit "geth initialization failed";
        fi
        echo "===== Completed initialization of geth for private network =====";
}

function setup_admin_website
{
        ############################
        # Setup admin website
        ############################
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
	printf "%s\n" "BOOTNODE_URLS=\"${BOOTNODE_URLS[*]}\"" >> $GETH_CFG_FILE_PATH;
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
          printf "%s\n" "BOOTNODES=\"${BOOTNODES[*]}\"" >> $GETH_CFG_FILE_PATH;
	  printf "%s\n" "ADMIN_SITE_PORT=$ADMIN_SITE_PORT" >> $GETH_CFG_FILE_PATH;
          printf "%s\n" "masterkey=$masterkey" >> $GETH_CFG_FILE_PATH;
          printf "%s\n" "endpointurl=$endpointurl" >> $GETH_CFG_FILE_PATH;
          printf "%s\n" "dbname=$dbname" >> $GETH_CFG_FILE_PATH;
          printf "%s\n" "collname=$collname" >> $GETH_CFG_FILE_PATH;

	fi
}

function setup_rc_local
{
        echo "===== Setting up rc.local for restart on VM reboot =====";
        echo -e '#!/bin/bash' "\nsudo -u $AZUREUSER /bin/bash $HOMEDIR/start-private-blockchain-sm.sh $GETH_CFG_FILE_PATH $PASSWD" | sudo tee /etc/rc.local 2>&1 1>/dev/null
        if [ $? -ne 0 ]; then
	        unsuccessful_exit "failed to setup rc.local for restart on VM reboot";
        fi
        echo "===== Completed setting up rc.local for restart on VM reboot =====";
}

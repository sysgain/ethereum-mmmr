#!/bin/bash

#installing prerequisites
#npm
sudo apt-get install npm -y >/dev/null 2>&1
#nodejs
sudo apt-get install nodejs -y >/dev/null 2>&1
#install the crypto-js module for nodejs
sudo npm install crypto-js >/dev/null 2>&1
#grab all the command line arguments into the corresponding variables
masterkey=$1
requesturl=$2
verb=$3
requesturllength=`echo $requesturl | wc -c`
#move to the home folder
cd ~
#download the nodejs code for authstring generation
#wget https://raw.githubusercontent.com/pradeepts/testRepo/master/authGen.js
output=`nodejs authTokenGenerator.js $masterkey $requesturl $verb`
DATE=`echo $output | cut -d "=" -f2 |cut -c2-30`
URL=`echo $output | cut -d "=" -f3 |cut -c2-$requesturllength`
AUTHSTRING=`echo $output | cut -d "=" -f4 |cut -c2-89`
DATA=$4
#echo "date:$DATE"
#echo "url:$URL"
#echo "authstring:$AUTHSTRING"
#get all the documents from document db
get()
{
curloutput=`curl -s -X GET $URL -H 'Accept: application/json' -H "Authorization: ${AUTHSTRING}" -H "x-ms-date: ${DATE}" -H 'x-ms-version: 2016-07-11'`
echo $curloutput
}
post()
{
curl -X POST $URL -H "Authorization: ${AUTHSTRING}" -H "x-ms-date: ${DATE}" -H 'x-ms-version: 2016-07-11' -d "$DATA" >/dev/null 2>&1
}
if [ "$verb" = "get" ]
then
get
else
post
fi
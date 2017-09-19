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
output=`nodejs auth-token-generator.js $masterkey $requesturl $verb`
DATE=`echo $output | cut -d "=" -f2 |cut -c2-30`
URL=`echo $output | cut -d "=" -f3 |cut -c2-$requesturllength`
AUTHSTRING=`echo $output | cut -d "=" -f4 |cut -c2-89`
DATA=$4
echo "Registrar authentication token details"
echo "Date:$DATE"
echo "URL:$URL"
echo "Authstring:$AUTHSTRING"
#get all the documents from document db
get()
{
curloutput=`curl -s -X GET $URL -H 'Accept: application/json' -H "Authorization: ${AUTHSTRING}" -H "x-ms-date: ${DATE}" -H 'x-ms-version: 2017-02-22'`
echo $curloutput
}
post()
{
curl -X POST $URL -H "Authorization: ${AUTHSTRING}" -H "x-ms-date: ${DATE}" -H 'x-ms-version: 2017-02-22' -d "$DATA" >/dev/null 2>&1
}
put()
{
curl -X PUT $URL -H "Authorization: ${AUTHSTRING}" -H "x-ms-date: ${DATE}" -H 'x-ms-version: 2017-02-22' -d "$DATA" >/dev/null 2>&1
}
if [ "$verb" = "get" ]
then
get
elif [ "$verb" = "post" ]
then
post
else
put
fi
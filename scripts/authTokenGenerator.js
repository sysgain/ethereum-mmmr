var CryptoJS = require("crypto-js");
// store our master key for documentdb
var mastKey = process.argv[2];
// Grab the request url
var url = process.argv[3];
// assign our verb
var verb = process.argv[4];
// store our date as RFC1123 format for the request
var today = new Date();
var UTCstring = today.toUTCString();
console.log("date = " + UTCstring);
console.log("requestURL = " + url);

// strip the url of the hostname up and leading slash
var strippedurl = url.replace(new RegExp('^https?://[^/]+/'),'/');

// push the parts down into an array so we can determine if the call is on a specific item
// or if it is on a resource (odd would mean a resource, even would mean an item)
var strippedparts = strippedurl.split("/");
var truestrippedcount = (strippedparts.length - 1);

// define resourceId/Type now so we can assign based on the amount of levels
var resourceId = "";
var resType = "";

// its odd (resource request)
if (truestrippedcount % 2)
{
   // assign resource type to the last part we found.
    resType = strippedparts[truestrippedcount];
    if (truestrippedcount > 1)
    {
        // now pull out the resource id by searching for the last slash and substringing to it.
        var lastPart = strippedurl.lastIndexOf("/");
        resourceId = strippedurl.substring(1,lastPart);
    }
}
else // its even (item request on resource)
{
    // assign resource type to the part before the last we found (last is resource id)
    resType = strippedparts[truestrippedcount - 1];

    // finally remove the leading slash which we used to find the resource if it was only one level deep.
    strippedurl = strippedurl.substring(1);

    // assign our resourceId
    resourceId = strippedurl;
}

// assign our RFC 1123 date
var date = UTCstring.toLowerCase();

// parse our master key out as base64 encoding
var key = CryptoJS.enc.Base64.parse(mastKey);


// build up the request text for the signature so can sign it along with the key
var text = (verb || "").toLowerCase() + "\n" +
               (resType || "").toLowerCase() + "\n" +
               (resourceId || "") + "\n" +
               (date || "").toLowerCase() + "\n" +
               "" + "\n";

// create the signature from build up request text
var signature = CryptoJS.HmacSHA256(text, key);


// back to base 64 bits
var base64Bits = CryptoJS.enc.Base64.stringify(signature);

// format our authentication token and URI encode it.
var MasterToken = "master";
var TokenVersion = "1.0";
auth = encodeURIComponent("type=" + MasterToken + "&ver=" + TokenVersion + "&sig=" + base64Bits);
console.log("authToken = " + auth);
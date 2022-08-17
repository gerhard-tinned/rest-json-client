# The rest-JSON client

The rest-json is a very simple shell script implementation allowing to interact with a rest/json API. 

The script allows to define a JSON template for each request available via the API. Additionally to the JSON template, a configuration file allows to set parameters for the request. 

## Requirements

This script uses internally the following tools which must be installed. 

* jq

Besides the Linux core utilities, the script requires "jq" to be installed which is used to parse the JSON response from the API.


## Configuration

A generic configuration file is available in the template directory called "_api.conf". It contains the URL (without the API path) to the API server.

```
REQUEST_URL="https://api.host.example.com"
```

This configuration should contain the URL without the path. The path will be configured per request.


## JSON template

The JSON template contains the JSON that will be sent in the requests to the API. All parameters should be replaced with placeholders of the format "#PARAMETERNAME#" (The parameter-name surrounded by '#'). Each line must only contain one parameter placeholder. 

The placeholder name is also the name used as the Name to set the value for that parameter. Lines with parameters which are not defined in the request will be removed. 

### Limitation

Based on the fact that not set parameters are removed from the final JSON, make sure that at least one mandatory parameter is set as last element in the JSON template. Otherwhise the last element might end with a "," rendering the JSON invalid.

## CFG files

The config files contain configuration elements for the request.

```
REQUEST_PATH="/api/path/name"
REQUEST_TYPE="POST"
# VARIABLES from the input are prefixed with "JSONSV_"
REQUEST_HEADER="Authorization: Token ${JSONSV_TOKEN}"

RESULT_FIELDS=".result[0].error_msg"
OK_FIELD_CHECK=".result[0].datafield"
ERROR_FIELDS=".status_code .status .error_message"
```

* The REQUEST_PATH is concatinated to the REQUEST_URL from the "_api.conf" file to form the URL used to send the request.
* The REQUEST_TYPE sets the type of request POST/PUT/DELETE sent to the API.
* The REQUEST_HEADER allows (optionally) to set additional http request headers for the request.

* The RESULT_FIELDS is a space separated list of field identifies in jq format. The fields returned on a successful request.
* The OK_FIELD_CHECK is a single field identifies of query in jq format. If the field is returned by the jq query, the request is considered successful.
* The ERROR_FIELDS is a space separated list of field identifies in jq format. The list of fields is returned when the request was not successful (OK_FIELD_CHECK field not returned).

The jq query format allows not only for identifying a specific field in the returned JSON but allows also checking the content. As of this, the jq query can be written to only return a field if it contains a certain value. That can be used to check if the request was successful.

```
OK_FIELD_CHECK="if .status == \"OK\" then .status else empty end"

```

The above example for the OK_FIELD_CHECK configuration will only return the status field of the returned JSON if the value of the field is "OK". This way, not only the presents of a field cxan be verified but also the value returned.


## Calling the script 

```
$ ./rest-json-client.sh -h

Usage: rest-json-client.sh [-hvd] --tpath /path/to/tmplates/ --request NAME --list VARIABLES
  -h  --help              print this usage and exit
  -v  --version           print version information and exit
  -d                      Enable the debug output
  -t  --tpath DIR         Directory containing the request templates
                          default is the script path subdirectory json_tmpl
  -r  --request NAME      The name or the request to perform
      --list              List the templates request variables and response variables
                          When given without a request name, the available requests are listed

VARIABLES can be set as environment variables or as arguments in the following format
      NAME value          The variables can be passed to the script as arguments
```

In usual Rest/JSON APIs the first request needed is the authentication request. It is suggested to define the RESULT_FIELDS in a way that it can be used in the requests after. 

```
./rest-json-client.sh -r authenticate USERNAME user1 PASSWORD 'Pa55wordUser1'
TOKEN "e9af28db0d3fe31c834c6d9e5f3af3a3a3d9457d"
```

When configured in the correct way (like shown above), the resulting field will be the session token required for the requests after the authentication. Sometimes it can be enough to store the output on a variable to be used in following requests.


```
SESSION_TOKEN=$(./rest-json-client.sh -r authenticate USERNAME user1 PASSWORD 'Pa55wordUser1')
```


## Showing Request Information

The script allows to list the available request using the "--list" option. 

```
$ $ ./rest-json-client.sh --list
authenticate
request_a
request_b
```

Combined with the "-r" option and a request name with the "--list" option, the list of variables in the template are listed as well as the returned Fields from the response.

```
$ ./rest-json-client.sh --list -r authenticate

# authenticate

## Request Variables
* USERNAME
* PASSWORD

## Response Variables
* TOKEN
```


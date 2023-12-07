#!/bin/bash
# 
VERSION="0.3.0"
#

#
# Help screen
#
function help_screen () {
    echo 
    echo "Usage: $(basename $0) [-hvd] --tpath /path/to/tmplates/ --request NAME --list VARIABLES"
    echo "  -h  --help              print this usage and exit"
    echo "  -v  --version           print version information and exit"
    echo "  -d                      Enable the debug output"
    echo "  -t  --tpath DIR         Directory containing the request templates "
    echo "                          default is the script path subdirectory json_tmpl"
    echo "  -r  --request NAME      The name or the request to perform"
    echo "      --list              List the templates request variables and response variables"
    echo "                          When given without a request name, the available requests are listed"
    echo ""
    echo "VARIABLES can be set as environment variables or as arguments in the followiug format"
    echo "      NAME value          The variables can be passed to the script as arguments "
}

function errorout () {
    echo -e "$@" >&2
}

function echoout () {
    echo -e "$@"
}

function formatout () {
    FORMATOUT_FORMAT=$1
    shift
    printf "${FORMATOUT_FORMAT}" $@
}

function debugout () {
    # Send debug output when debug mode is enabled
    if [[ ${DEBUG} != 0 ]]; then
        echo -e "$(date "+%F %T") - $@" >&2
    fi
}

OSTYPE=$(uname -s)

if [[ "${OSTYPE}" == "Darwin" ]]; then
    TEMPLATE_PATH="$(dirname $0)/json_tmpl"
else
    TEMPLATE_PATH="$(dirname $(readlink -f $0))/json_tmpl"
fi

DEBUG=0
while [ $# -gt 0 ]; do
    case $1 in
        # General parameter
        -h|--help)
            help_screen
            exit 0
            ;;

        -v|--version)
            echo 
            echo "`basename $0` version ${VERSION}"
            echo
            exit 0
            ;;

        -d)
            DEBUG=1
            shift 1
            ;;

        -t|--tpath)
            if [[ ! -z "$2" ]] && [[ -d "$2" ]]; then
                TEMPLATE_PATH=$2
            else
                echo "ERROR: Specified template directory '${TEMPLATE_PATH}' does not exist or is not a directory."
                help_screen
                exit 1
            fi
            shift 2
            ;;

        -r|--request)
            if [[ ! -z "$2" ]] && [[ -f "${TEMPLATE_PATH}/$2.json" ]]; then
                REQUEST_NAME=$2
            else
                echo "ERROR: Specified template '${TEMPLATE_PATH}/$2.json' or directory does not exist or is not a directory."
                help_screen
                exit 1
            fi
            shift 2
            ;;

        -l|--list)
            COMMAND="LIST"
            shift 1
            ;;

        # VARIABLES        
        *)
            if [[ "${1}" == "$(echo ${1} | egrep '^[0-9A-Z_]+$')" ]] && [[ ! -z "$2" ]]; then
                export JSONSV_${1}="${2}"
                shift 2
            else
                echo "ERROR: Unknown option '$1'"
                help_screen
                exit 1
                break
            fi
            ;;
    esac
done


# load the PAI configuration
. ${TEMPLATE_PATH}/_api.conf


#
# List available requests
#
if [[ "${COMMAND}" == "LIST" ]] && [[ -z "${REQUEST_NAME}" ]]; then
    find ${TEMPLATE_PATH} -name '*.json' | sed -Ee 's|^.*/([a-z_]+)\.json|\1|'
    exit 0
fi


#
# List Request variables and response variables
#
if [[ "${COMMAND}" == "LIST" ]]; then
    if [[ -f "${TEMPLATE_PATH}/${REQUEST_NAME}.json" ]]; then
        FIELDS=$(egrep '#[0-9A-Z_]+#' ${TEMPLATE_PATH}/${REQUEST_NAME}.json | sed -Ee 's/^.*#([0-9A-Z_]+)#.*$/\1/')
        . ${TEMPLATE_PATH}/${REQUEST_NAME}.cfg

        echoout ""
        echoout "# ${REQUEST_NAME}"
        echoout ""
        echoout "## Request Variables"
        for F in ${FIELDS}; do
            echoout "* ${F}"
        done
        echoout ""
        echoout "## Response Variables"
        for F in ${RESULT_FIELDS}; do
            echoout "* $(echo ${F} | awk -F "." '{print $NF}' | tr '[:lower:]' '[:upper:]') "
        done
        echoout ""
    else 
        errorout "Unknown request '${REQUEST_NAME}'."
        exit 1
    fi
    exit 0
fi

# Reading files
if [[ -f "${TEMPLATE_PATH}/${REQUEST_NAME}.json" ]]; then
    FIELDS=$(egrep '#[0-9A-Z_]+#' ${TEMPLATE_PATH}/${REQUEST_NAME}.json | sed -Ee 's/^.*#([0-9A-Z_]+)#.*$/\1/')
    . ${TEMPLATE_PATH}/${REQUEST_NAME}.cfg
    TMP_FILE=$(umask 077 && mktemp /tmp/rest-json.XXXXXXXXXX)
else 
    errorout "Request template could not be found."
    exit 1
fi

# Reading VARIABLES from the request file
FIELD_REPLACE=""
for F in ${FIELDS}; do
    SF="JSONSV_${F}"
    if [[ ! -z "${!SF}" ]]; then
        FIELD_REPLACE="${FIELD_REPLACE} -e 's|#${F}#|${!SF}|' "
    fi
done

# Replacing the variables with content ; Removing elements with NO variables value
echo sed ${FIELD_REPLACE} ${TEMPLATE_PATH}/${REQUEST_NAME}.json | bash | egrep -v "#[0-9A-Z_]+#" >${TMP_FILE}


if [[ "${DEBUG}" == "1" ]]; then
    debugout "## REQUEST JSON"
    debugout "$(cat ${TMP_FILE} )"
    debugout "\n"
fi



# send request
if [[ "${DEBUG}" == "1" ]]; then
    DEBUG_OPTIONS=" -v "
else
    DEBUG_OPTIONS=""
fi

# Set additional request header
debugout "## REQUST COMMAND"
if [[ -z "${REQUEST_HEADER}" ]]; then
    debugout "     curl -sS -k --request \"${REQUEST_TYPE}\" --header \"Content-Type: application/json\" --data @${TMP_FILE} \"${REQUEST_URL}${REQUEST_PATH}\" ${DEBUG_OPTIONS}"
    debugout "\n"
    RESPONSE_RAW=$(curl -sS -k --request  "${REQUEST_TYPE}"  --header  "Content-Type: application/json"  --data @${TMP_FILE}  "${REQUEST_URL}${REQUEST_PATH}"  ${DEBUG_OPTIONS} )
else
    debugout "     curl -sS -k --request \"${REQUEST_TYPE}\" --header \"Content-Type: application/json\" --header \"${REQUEST_HEADER}\" --data @${TMP_FILE} \"${REQUEST_URL}${REQUEST_PATH}\" ${DEBUG_OPTIONS}"
    debugout "\n"
    RESPONSE_RAW=$(curl -sS -k --request  "${REQUEST_TYPE}"  --header  "Content-Type: application/json"  --header  "${REQUEST_HEADER}"  --data @${TMP_FILE}  "${REQUEST_URL}${REQUEST_PATH}" ${DEBUG_OPTIONS} )
fi

debugout "## RESPONSE_RAW"
debugout "$(echo "${RESPONSE_RAW}" | jq)"
debugout "\n"



# Check the response
OK_CHECK=$(echo ${RESPONSE_RAW} | jq "${OK_FIELD_CHECK}")
if [[ -z "${OK_CHECK}" ]] || [[ "${OK_CHECK}" == "null" ]]; then
    debugout "*** ERROR ***"
    for EF in ${ERROR_FIELDS}; do
        EF_VALUE=$(echo ${RESPONSE_RAW} | jq "${EF}")
        echoout "$(echo ${EF} | awk -F "." '{print $NF}' | tr '[:lower:]' '[:upper:]') ${EF_VALUE}"
    done
else
    debugout "*** SUCCESS ***"
    for RF in ${RESULT_FIELDS}; do
        RF_VALUE=$(echo ${RESPONSE_RAW} | jq "${RF}" )
        echoout "$(echo ${RF} | awk -F "." '{print $NF}' | tr '[:lower:]' '[:upper:]') ${RF_VALUE}"
    done
fi
echoout "\n"


rm ${TMP_FILE}

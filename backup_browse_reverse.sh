#!/usr/bin/env bash

# result of `ls` separated with newline for easier iteration
IFS='
'

MODE_AWS="aws"
MODE_LINODE="linode"
MODE_BACKBLAZE="backblaze"

REGEX_MODES='aws|linode|backblaze'
REGEX_FILENAME='^[a-z]{16}$'

ARG_MODE=""
ARG_PATH_LOGDIR=""

CONFIG_MODE=""
CONFIG_PATH_LOGDIR=""

PATH_STORAGE=""
PATH_CURRENT="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
PATH_FILE_CONFIG=$PATH_CURRENT/backup.config

COUNT_FILES_TOTAL=0
COUNT_FILES_FOUND=0
COUNT_FILES_NOT_FOUND=0

B2_BUCKETS=""
DATE=$(date +"%Y-%m-%d_%H-%M")

BUCKET_CONTENTS=""

EXIT_CODE_SUCCESS=0

while [[ $# -gt 0 ]]
do
key="$1"
case $key in
    -m|--mode)
    ARG_MODE="$2"
    shift # past argument
    shift # past value
    ;;
    *)
    ARG_PATH_LOGDIR="$1"
    shift
esac
done

function load_config ()
{
    if [[ -f $PATH_FILE_CONFIG ]];then
        echo '[→] Loading the configuration file'
        . $PATH_FILE_CONFIG
    fi
}

function requirements ()
{
    if [[ $CONFIG_MODE = $MODE_LINODE ]];then
        type linode-cli
    fi
    if [[ $CONFIG_MODE = $MODE_AWS ]];then
        type aws
    fi
    if [[ $CONFIG_MODE = $MODE_BACKBLAZE ]];then
        type b2
    fi
}

function args_validate ()
{
    exit_code_args=$EXIT_CODE_SUCCESS
    if [[ "$ARG_MODE" =~ $REGEX_MODES ]];then
        CONFIG_MODE=$ARG_MODE
    else
        exit_code_args=1
    fi
    if [[ -d "$ARG_PATH_LOGDIR" ]];then
        CONFIG_PATH_LOGDIR=$ARG_PATH_LOGDIR;
    else
        echo "[✗] The backup dictionary directory doesn't exist ${ARG_PATH_LOGDIR}"
        exit_code_args=1
    fi
    if [[ $CONFIG_MODE = $MODE_LINODE ]];then
        PATH_STORAGE=$PATH_STORAGE_LINODE
    fi
    if [[ $CONFIG_MODE = $MODE_AWS ]];then
        PATH_STORAGE=$PATH_STORAGE_AWS
    fi
    if [[ $CONFIG_MODE = $MODE_BACKBLAZE ]];then
        PATH_STORAGE=$PATH_STORAGE_BACKBLAZE
    fi
    return $exit_code_args
}

function bucket_fetch_content ()
{
    exit_code_ls=1
    echo "[→] Checking on remote storage for path ${PATH_STORAGE}"
    if [[ $CONFIG_MODE = $MODE_LINODE ]];then
      exit_code_ls=1
    fi
    if [[ $CONFIG_MODE = $MODE_AWS ]];then
      exit_code_ls=1
    fi
    if [[ $CONFIG_MODE = $MODE_BACKBLAZE ]];then
      BUCKET_CONTENTS=$(b2 ls "b2://${PATH_STORAGE}")
      exit_code_ls=$?
    fi
    return $exit_code_ls
}
function objects_lookup ()
{
    for item_backup in $BUCKET_CONTENTS; do
      COUNT_FILES_TOTAL=$((COUNT_FILES_TOTAL+1))
      item_details=$(grep -nH -w -r $item_backup $CONFIG_PATH_LOGDIR)
      if [ $? -eq 0 ]; then
        COUNT_FILES_FOUND=$((COUNT_FILES_FOUND+1))
        echo "[✔] Object known ${item_details}"
      else
        COUNT_FILES_NOT_FOUND=$((COUNT_FILES_NOT_FOUND+1))
        echo "[✗] Object unknown ${item_backup}"
      fi
    done
    echo "[i] (${COUNT_FILES_FOUND} of ${COUNT_FILES_TOTAL}) objects on the remote storage are known"
    echo "[i] (${COUNT_FILES_NOT_FOUND} of ${COUNT_FILES_TOTAL}) objects on the remote storage are unknown"
}

function run ()
{
    load_config
    args_validate
    if [ $? -eq 0 ]
    then
      bucket_fetch_content
      if [ $? -eq 0 ]; then
        objects_lookup
      fi
    else
      echo '[✗] Invalid arguments'
    fi
}

run

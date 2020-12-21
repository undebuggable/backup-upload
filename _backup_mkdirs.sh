#!/usr/bin/env bash

MODE_AWS="aws"
MODE_LINODE="linode"
MODE_BACKBLAZE="backblaze"

REGEX_MODES='aws|linode|backblaze'

PATH_LOCAL_DOWNLOAD=""
PATH_LOCAL_UPLOAD=""

CONFIG_MODE=""

while [[ $# -gt 0 ]]
do
key="$1"
case $key in
    -m|--mode)
    ARG_MODE="$2"
    shift # past argument
    shift # past value
    ;;
esac
done

function load_config ()
{
    if [[ -f $PATH_FILE_CONFIG ]];then
        echo "[→] Loading the configuration file"
        . $PATH_FILE_CONFIG
    fi
}

function args_validate ()
{
    return_code=0
    if [[ "$ARG_MODE" =~ $REGEX_MODES ]];then
        CONFIG_MODE=$ARG_MODE
    else
        return_code=1
    fi
    if [[ $CONFIG_MODE = $MODE_LINODE ]];then
        PATH_LOCAL_UPLOAD=$PATH_LOCAL_UPLOAD_LINODE
        PATH_LOCAL_DOWNLOAD=$PATH_LOCAL_DOWNLOAD_LINODE
    fi
    if [[ $CONFIG_MODE = $MODE_AWS ]];then
        PATH_LOCAL_UPLOAD=$PATH_LOCAL_UPLOAD_AWS
        PATH_LOCAL_DOWNLOAD=$PATH_LOCAL_DOWNLOAD_AWS
    fi
    if [[ $CONFIG_MODE = $MODE_BACKBLAZE ]];then
        PATH_LOCAL_UPLOAD=$PATH_LOCAL_UPLOAD_BACKBLAZE
        PATH_LOCAL_DOWNLOAD=$PATH_LOCAL_DOWNLOAD_BACKBLAZE
    fi
    return $return_code
}

function mkdirs ()
{
  if [ ! -d "$PATH_LOCAL_BASEDIR" ]; then
      mkdir $PATH_LOCAL_BASEDIR
  fi
  if [ ! -d "$PATH_LOCAL_UPLOAD" ]; then
      mkdir $PATH_LOCAL_UPLOAD
  fi
  if [ ! -d "$PATH_LOCAL_DOWNLOAD" ]; then
      mkdir $PATH_LOCAL_DOWNLOAD
  fi
}

function run ()
{
    load_config
    args_validate
    mkdirs
}

run

#!/usr/bin/env bash

MODE_AWS="aws"
MODE_LINODE="linode"
MODE_BACKBLAZE="backblaze"

REGEX_MODES='aws|linode|backblaze'
REGEX_FILENAME='^[a-z]{16}$'

ARG_MODE=""
ARG_PATH_LOGFILE=""

CONFIG_MODE=""
CONFIG_PATH_LOGFILE=""

PATH_STORAGE=""
PATH_CURRENT="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
PATH_FILE_CONFIG=$PATH_CURRENT/backup.config

COUNT_FILES_TOTAL=0
COUNT_FILES_FOUND=0
COUNT_FILES_NOT_FOUND=0

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
    ARG_PATH_LOGFILE="$1"
    shift
esac
done

function load_config ()
{
    if [[ -f $PATH_FILE_CONFIG ]];then
        echo "[→] Loading the configuration file"
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
    return_code=0
    if [[ "$ARG_MODE" =~ $REGEX_MODES ]];then
        CONFIG_MODE=$ARG_MODE
    else
        return_code=1
    fi
    if [[ -f "$ARG_PATH_LOGFILE" ]];then
        CONFIG_PATH_LOGFILE=$ARG_PATH_LOGFILE;
    else
        echo "[✗] The backup dictionary file doesn't exist "$ARG_PATH_LOGFILE
        return_code=1
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
    return $return_code
}

function check_file ()
{
    path_storage_base="$1"
    filename_obscured="$2"
    path_storage=$path_storage_base/$filename_obscured
    aws_ls_retval=-1
    echo "[→] Checking on cloud storage for path "$path_storage
    if [[ $CONFIG_MODE = $MODE_LINODE ]];then
        linode_ls_ret=$(linode-cli obj ls $path_storage | grep $filename_obscured)
        if [[ $linode_ls_ret = "" ]];then
            aws_ls_retval=1
        else
            aws_ls_retval=0
        fi
    fi
    if [[ $CONFIG_MODE = $MODE_AWS ]];then
        aws --profile $AWS_PROFILE s3 ls $path_storage
        aws_ls_retval=$?
    fi
    if [[ $CONFIG_MODE = $MODE_BACKBLAZE ]];then
        backblaze_ls_ret=$(b2 ls $path_storage_base | grep $filename_obscured)
        if [[ $backblaze_ls_ret = "" ]];then
            aws_ls_retval=1
        else
            aws_ls_retval=0
        fi

    fi
    return $aws_ls_retval
}

function parse_logfile_item ()
{
    filename_plaintext="$1"
    filename_obscured="$2"
    if [[ "$filename_obscured" =~ $REGEX_FILENAME ]]; then
        COUNT_FILES_TOTAL=$((COUNT_FILES_TOTAL+1))
        check_file $PATH_STORAGE $filename_obscured
        aws_ls_retval=$?
        if [[ $aws_ls_retval = 0 ]]; then
            COUNT_FILES_FOUND=$((COUNT_FILES_FOUND+1))
            echo \
                "[✔] Object exists on cloud storage "\
                $filename_plaintext $filename_obscured
        elif [[ $aws_ls_retval = 1 ]]; then
            COUNT_FILES_NOT_FOUND=$((COUNT_FILES_NOT_FOUND+1))
            echo \
                "[✗] Object does not exist on cloud storage "\
                $filename_plaintext $filename_obscured
        fi
    else
        echo "[✗] No obscured filename found for log entry "$filename_plaintext
    fi
}

function parse_logfile ()
{
    exec 3< $CONFIG_PATH_LOGFILE

    while read filename_plaintext <&3 ; do
        read checksum_line <&3
        read filename_obscured <&3
        parse_logfile_item $filename_plaintext $filename_obscured
    done
    # Close file handle 3
    exec 3<&-

    echo "[i] ("\
        $COUNT_FILES_FOUND\
        "of"\
        $COUNT_FILES_TOTAL\
        ") objects found on the cloud storage"
    echo "[i] ("\
        $COUNT_FILES_NOT_FOUND\
        "of"\
        $COUNT_FILES_TOTAL\
        ") objects not found on the cloud storage"
}

function run ()
{
    load_config
    args_validate
    code_validation=$?
    if [[ $code_validation = 0 ]];then
        requirements
        parse_logfile
    else
        echo "[✗] Invalid arguments"
    fi
}

run

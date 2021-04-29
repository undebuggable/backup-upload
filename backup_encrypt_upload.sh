#!/usr/bin/env bash

# Enable iterating over filenames starting with a dot
shopt -s dotglob
# result of `ls` separated with newline for easier iteration
IFS='
'

UUID_LENGTH=16
UUID_CHARSET='a-z'
UUID_CURRENT=""

FILES_TOTAL=0

declare -a ARR_PATH=()

OS_MACOS=0
OS_LINUX=1
OS_CURRENT=-1

MODE_AWS="aws"
MODE_LINODE="linode"
MODE_BACKBLAZE="backblaze"

REGEX_MODES='aws|linode|backblaze'

ARG_MODE=""
ARG_PATH_LOGFILE=""
ARG_PATH_BACKUP=""

CONFIG_MODE=""
CONFIG_PATH_LOGFILE=""
CONFIG_PATH_BACKUP=""

PATH_STORAGE=""
PATH_LOCAL_UPLOAD=""
PATH_CURRENT="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
PATH_FILE_CONFIG=$PATH_CURRENT/backup.config

while [[ $# -gt 0 ]]
do
key="$1"
case $key in
    -l|--path-logfile)
    ARG_PATH_LOGFILE="$2"
    shift # past argument
    shift # past value
    ;;
    -b|--path-backup)
    ARG_PATH_BACKUP="$2"
    shift # past argument
    shift # past value
    ;;
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

function requirements ()
{
    type basename
    type sha256sum
    if [[ $OS_CURRENT = $OS_LINUX ]]; then
        type gpg2
    fi
    if [[ $OS_CURRENT = $OS_MACOS ]]; then
        type gpg
    fi
    if [[ $CONFIG_MODE = $MODE_LINODE ]];then
        type linode-cli
        type s3cmd
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
    CONFIG_PATH_BACKUP=$ARG_PATH_BACKUP;
    if [[ "$ARG_MODE" =~ $REGEX_MODES ]];then
        CONFIG_MODE=$ARG_MODE
    else
        return_code=1
    fi
    if [[ -f "$ARG_PATH_LOGFILE" ]];then
        echo "[✗] The backup dictionary file already exists "$ARG_PATH_LOGFILE
        return_code=1
    else
        CONFIG_PATH_LOGFILE=$ARG_PATH_LOGFILE;
    fi
    if [[ $CONFIG_MODE = $MODE_LINODE ]];then
        PATH_STORAGE=$PATH_STORAGE_LINODE
        PATH_LOCAL_UPLOAD=$PATH_LOCAL_UPLOAD_LINODE
    fi
    if [[ $CONFIG_MODE = $MODE_AWS ]];then
        PATH_STORAGE=$PATH_STORAGE_AWS
        PATH_LOCAL_UPLOAD=$PATH_LOCAL_UPLOAD_AWS
    fi
    if [[ $CONFIG_MODE = $MODE_BACKBLAZE ]];then
        PATH_STORAGE=$PATH_STORAGE_BACKBLAZE
        PATH_LOCAL_UPLOAD=$PATH_LOCAL_UPLOAD_BACKBLAZE
    fi
    return $return_code
}

function detect_os ()
{
  if [[ "$OSTYPE" == "linux"* ]]; then
    OS_CURRENT=$OS_LINUX
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    OS_CURRENT=$OS_MACOS
  else
    OS_CURRENT=$OS_LINUX
  fi
}

function os_gpg ()
{
  path_encrypt="$1"
  if [[ $OS_CURRENT = $OS_LINUX ]]; then
        gpg2 --trust-model always -e -r $GPG_RECIPIENT $path_encrypt;
  fi
  if [[ $OS_CURRENT = $OS_MACOS ]]; then
        gpg --trust-model always -e -r $GPG_RECIPIENT $path_encrypt;
  fi
}

function os_uuid ()
{
  UUID_CURRENT=""
  if [[ $OS_CURRENT = $OS_LINUX ]]; then
      UUID_CURRENT=$(\
        cat /dev/urandom | \
        env tr -cd $UUID_CHARSET | \
        head -c $UUID_LENGTH \
      )
  fi
  if [[ $OS_CURRENT = $OS_MACOS ]]; then
      UUID_CURRENT=$(\
        cat /dev/urandom | \
        env LC_CTYPE=C tr -cd $UUID_CHARSET | \
        head -c $UUID_LENGTH \
      )
  fi
}

function create_file_list ()
{
    list_files=$(ls -dlhS $CONFIG_PATH_BACKUP*)
    for list_item in $list_files
    do
        path_backup=$(echo $list_item | awk '{print $9}');
        if [[ -f $path_backup ]];then
            ARR_PATH[$((FILES_TOTAL))]=$path_backup
            FILES_TOTAL=$((FILES_TOTAL+1))
        fi
    done
}

function upload ()
{
    path_backup="$1"
    path_to_upload="$2"
    echo "[→] Uploading "$path_backup;
    if [[ $CONFIG_MODE = $MODE_LINODE ]];then
        # s3cmd will transparently take care of the Linode's limit of 5GB per object
        s3cmd put $path_to_upload $PATH_STORAGE;
    fi
    if [[ $CONFIG_MODE = $MODE_AWS ]];then
        aws --profile $AWS_PROFILE s3 mv $path_to_upload $PATH_STORAGE;
    fi
    if [[ $CONFIG_MODE = $MODE_BACKBLAZE ]];then
        b2 upload-file $PATH_STORAGE $path_to_upload $UUID_CURRENT;
    fi
    upload_exit_code=$?
    if [[ $upload_exit_code = 0 ]]; then
        echo "[✔] Object uploaded"
        if [[ -f $path_to_upload ]];then
            rm -f $path_to_upload
        fi
    elif [[ $upload_exit_code = 1 ]]; then
        echo "[✗] Object upload failed"
    fi
}

function encrypt ()
{
    path_backup="$1"
    echo "[→] Calculating checksum "$path_backup
    basename $path_backup >> $CONFIG_PATH_LOGFILE;
    sha256sum $path_backup >> $CONFIG_PATH_LOGFILE;
    echo $UUID_CURRENT >> $CONFIG_PATH_LOGFILE;
    echo "[→] Encrypting "$path_backup;
    os_gpg $path_backup
    rm -f $path_backup;
    mv $path_backup.gpg $PATH_LOCAL_UPLOAD/$UUID_CURRENT;
}

function process_backup_files ()
{
    rm -f $CONFIG_PATH_LOGFILE;
    touch $CONFIG_PATH_LOGFILE;
    counter=$((FILES_TOTAL-1))
    while [ $counter -ge 0 ]; do
        path_backup=${ARR_PATH[$counter]}
        os_uuid
        encrypt $path_backup;
        upload $path_backup $PATH_LOCAL_UPLOAD/$UUID_CURRENT
        counter=$((counter-1))
    done
}

function run ()
{
    load_config
    detect_os
    args_validate
    if [ $? -eq 1 ]
    then
      requirements
      sh $PATH_CURRENT/_backup_mkdirs.sh -m $CONFIG_MODE
      create_file_list
      process_backup_files
    else
      echo "[✗] Invalid arguments"
    fi
}

run

#!/usr/bin/env bash

# Enable iterating over filenames starting with a dot
shopt -s dotglob
# result of `ls` separated with newline for easier iteration
IFS='
'

UUID_LENGTH=16
UUID_CHARSET='a-z'

FILES_TOTAL=0

declare -a ARR_PATH=()
declare -a ARR_UUID=()

STATUS_PLAINTEXT=-1
STATUS_ENCRYPTED=0

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

EXIT_CODE_SUCCESS=0

while [[ $# -gt 0 ]]
do
key="$1"
case $key in
    -l|--path-logfile)
    ARG_PATH_LOGFILE="$2"
    shift # past argument
    shift # past value
    ;;
    -m|--mode)
    ARG_MODE="$2"
    shift # past argument
    shift # past value
    ;;
    *)
    ARG_PATH_BACKUP="$1"
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
    exit_code_args=$EXIT_CODE_SUCCESS
    # add trailing slash if doesn't exist
    CONFIG_PATH_BACKUP="$(echo $ARG_PATH_BACKUP | sed 's![^/]$!&/!')"
    if [[ "$ARG_MODE" =~ $REGEX_MODES ]];then
        CONFIG_MODE=$ARG_MODE
    else
        exit_code_args=1
    fi
    if [[ -f "$ARG_PATH_LOGFILE" ]];then
        echo "[✗] The backup dictionary file already exists "$ARG_PATH_LOGFILE
        exit_code_args=1
    else
        CONFIG_PATH_LOGFILE=$ARG_PATH_LOGFILE;
    fi
    if [[ ! -d "$CONFIG_PATH_BACKUP" ]]; then
        echo \
          "[✗] The directory to be backup up does not exists "\
          $CONFIG_PATH_BACKUP
        exit_code_args=1
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
    return $exit_code_args
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

function os_uuid ()
{
  index="$1"
  uuid=""
  if [[ $OS_CURRENT = $OS_LINUX ]]; then
      uuid=$(\
        cat /dev/urandom | \
        env tr -cd $UUID_CHARSET | \
        head -c $UUID_LENGTH \
      )
  fi
  if [[ $OS_CURRENT = $OS_MACOS ]]; then
      uuid=$(\
        cat /dev/urandom | \
        env LC_CTYPE=C \
        tr -cd $UUID_CHARSET | \
        head -c $UUID_LENGTH \
      )
  fi
  ARR_UUID[$index]=$uuid
}

function os_gpg ()
{
  path_encrypt="$1"
  path_destination="$2"
  exit_code_gpg=1
  if [[ $OS_CURRENT = $OS_LINUX ]]; then
    gpg2 \
      --trust-model always \
      -e -r $GPG_RECIPIENT \
      -o $path_destination \
      $path_encrypt;
    exit_code_gpg=$?
  fi
  if [[ $OS_CURRENT = $OS_MACOS ]]; then
    gpg \
      --trust-model always \
      -e -r $GPG_RECIPIENT \
      -o $path_destination \
      $path_encrypt;
    exit_code_gpg=$?
  fi
  return $exit_code_gpg
}

function create_file_list ()
{
    list_files=$(ls -dS $CONFIG_PATH_BACKUP*)
    for list_item in $list_files
    do
        if [[ -f $list_item ]];then
            os_uuid $((FILES_TOTAL));
            ARR_PATH[$((FILES_TOTAL))]=$list_item
            FILES_TOTAL=$((FILES_TOTAL+1))
        fi
    done
}

function encrypt ()
{
    rm -f $CONFIG_PATH_LOGFILE;
    touch $CONFIG_PATH_LOGFILE;
    counter=$((FILES_TOTAL-1))
    while [ $counter -ge 0 ]; do
        path_backup=${ARR_PATH[$counter]}
        filename_uui=${ARR_UUID[$counter]}
        echo "[→] Calculating checksum "$path_backup
        basename $path_backup >> $CONFIG_PATH_LOGFILE;
        sha256sum $path_backup >> $CONFIG_PATH_LOGFILE;
        echo $filename_uui >> $CONFIG_PATH_LOGFILE;
        echo "[→] Encrypting "$path_backup;
        os_gpg $path_backup $PATH_LOCAL_UPLOAD/$filename_uui;
        exit_code_encrypt=$?
        if [[ $exit_code_encrypt = $EXIT_CODE_SUCCESS ]]; then
          mv \
            $PATH_LOCAL_UPLOAD/$filename_uui \
            $PATH_LOCAL_UPLOAD/$filename_uui"✔"
          rm -f $path_backup;
          echo "[✔] Encryption complete "$path_backup;
        else
          echo "[✗] Encryption failed "$path_backup;
        fi
        counter=$((counter-1))
    done
}

function upload ()
{
    counter=$((FILES_TOTAL-1))
    while [ $counter -ge 0 ]; do
        path_backup=${ARR_PATH[$counter]}
        filename_uui=${ARR_UUID[$counter]}
        path_to_upload=$PATH_LOCAL_UPLOAD/$filename_uui
        if [[ -f $path_to_upload"✔" ]];then
            mv $path_to_upload"✔" $path_to_upload
            echo "[→] Uploading "$path_backup;
            if [[ $CONFIG_MODE = $MODE_LINODE ]];then
                # s3cmd will transparently take care of
                # the Linode's limit of 5GB per object
                s3cmd put $path_to_upload $PATH_STORAGE;
            fi
            if [[ $CONFIG_MODE = $MODE_AWS ]];then
                aws --profile $AWS_PROFILE s3 mv $path_to_upload $PATH_STORAGE;
            fi
            if [[ $CONFIG_MODE = $MODE_BACKBLAZE ]];then
                b2 upload-file $PATH_STORAGE $path_to_upload $filename_uui;
            fi
            exit_code_upload=$?
            if [[ $exit_code_upload = $EXIT_CODE_SUCCESS ]]; then
                echo "[✔] Object uploaded "$path_backup
                if [[ -f $path_to_upload ]];then
                    rm -f $path_to_upload
                fi
            elif [[ $exit_code_upload = 1 ]]; then
                echo "[✗] Object upload failed "$path_backup
            fi
            counter=$((counter-1))
        else
            echo "[?] Waiting for "$path_backup
        fi
        sleep 1
    done
}

function run ()
{
    load_config
    detect_os
    args_validate
    if [ $? -eq 0 ]
    then
      requirements
      sh $PATH_CURRENT/_backup_mkdirs.sh -m $CONFIG_MODE
      create_file_list
      encrypt &
      pid_encrypt=$!
      upload &
      pid_upload=$!
      wait $pid_encrypt $pid_upload
    else
      echo "[✗] Invalid arguments"
    fi
}

run

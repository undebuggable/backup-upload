backup-upload
==========

Encrypt and upload the backup to your favourite cloud services provider as long as it's Amazon, Backblaze, or Linode.

Introduction
---------

The goal of this project is to encrypt and upload the backup without using any proprietary client applications or data formats. It's possible to revert the backup with the `cp` or `sync` CLI utility made available by the cloud services provider and then decrypt it with `gpg`.

This utilities are optimized to work with flat file structure containing only files, for example backup created by the utility [backup-stuff](). The files are encrypted and uploaded in the sequence from the smallest to the largest. It's possible to encrypt and upload the files sequentially, or encrypt and upload the files in two parallel processes. The former takes more time but is useful when there is few space available on the hard drive, the latter is useful when the hard drive space is not a concern. 

The supported shells are `bash` and `zsh`.

Examples
---------

Create the configuration file `backup.config` in the root directory of this project:

```bash
AWS_PROFILE="<awc_cli_profile_name>"

GPG_RECIPIENT="<gpg_receipient_email>"

PATH_STORAGE_AWS="s3://<bucket_name>"
PATH_STORAGE_LINODE="<bucket_name>"
PATH_STORAGE_BACKBLAZE="<bucket_name>"

PATH_LOCAL_BASEDIR="/tmp"

PATH_LOCAL_UPLOAD_AWS=$PATH_LOCAL_BASEDIR"/backup-upload"
PATH_LOCAL_UPLOAD_LINODE=$PATH_LOCAL_BASEDIR"/backup-upload"
PATH_LOCAL_UPLOAD_BACKBLAZE=$PATH_LOCAL_BASEDIR"/backup-upload"

PATH_LOCAL_DOWNLOAD_AWS=$PATH_LOCAL_BASEDIR"/backup-download"
PATH_LOCAL_DOWNLOAD_LINODE=$PATH_LOCAL_BASEDIR"/backup-download"
PATH_LOCAL_DOWNLOAD_BACKBLAZE=$PATH_LOCAL_BASEDIR"/backup-download"
```

Encrypt files in a directory specified with parameter `-b` and upload them to object storage on Linode. The backup dictionary file will be saved in file specified by the parameter `-l`. The encryption and uploading will be handled by two parallel processes:
```bash
backup_encrypt_upload_parallel.sh -m linode -b ~/backup -l ~/backup.log
```
Test the existence of backup:
```bash
backup_test.sh -m linode -l ~/backup.log
```
Delete the backup from the object storage:
```bash
`backup_delete.sh` -m linode -l ~/backup.log
```

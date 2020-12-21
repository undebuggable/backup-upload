backup-upload
==========

Encrypt and upload the backup to your favourite cloud services provider as long as it's Amazon, Backblaze, or Linode.

Introduction
---------

The goal of this project is to encrypt and upload the backup without using any proprietary client applications or data formats. It's possible to revert the backup with the `cp` or `sync` CLI utility made available by the cloud services provider and then decrypt it with `gpg`.

This utilities are optimized to work with flat file structure containing only files, for example backup created by the utility [backup-stuff](https://github.com/undebuggable/backup-stuff). The files are encrypted and uploaded in the sequence from the smallest to the largest. It's possible to encrypt and upload the files sequentially, or encrypt and upload the files in two parallel processes. The former takes more time but is useful when there is few space available on the hard drive, the latter is useful when the hard drive space is not a concern. 

The supported shells are `bash` and `zsh`.

The utilities in this toolset provide *create*, *read*, and *delete* operations on the backup:
- create - `backup_encrypt_upload.sh`, `backup_encrypt_upload_parallel.sh`
- read - `backup_download.sh`
- delete - `backup_delete.sh`

Test the  existence of backup with `backup_test.sh`.

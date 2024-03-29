Requirements
------------

Setup the CLI clients for the cloud service provider.

### Amazon S3

[Setup the CLI client for AWS S3.](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html)

Test the CLI client and the presence of backup bucket:
```bash
aws --profile <aws_cli_profile> s3 ls
```

### Linode object storage

[Setup the CLI client for Linode object storage.](https://www.linode.com/docs/guides/how-to-use-object-storage/) The `s3cmd` client is also needed in addition to the Linode's `linode-cli`. The `s3cmd` client will transparently take care of Linode's limit of 5GB per one object.

Test the CLI client and the presence of backup bucket:
```bash
linode-cli obj ls
s3cmd ls
```

### Backblaze object storage

[Setup the CLI client for Backblaze object storage.](https://www.backblaze.com/b2/docs/quick_command_line.html)

Test the CLI client and the presence of backup bucket:
```bash
b2 list-buckets
```

### Bucket permissions

The bucket permissions most likely should be configured to private ie. non world-readable, non world-writable. Reference the documentation of the cloud service provider for details.

Running the application
------------

Create the configuration file `backup.config` in the root directory of this project:

```bash
AWS_PROFILE='<awc_cli_profile_name>'

GPG_RECIPIENT='<gpg_receipient_email>'

PATH_STORAGE_AWS='s3://<bucket_name>'
PATH_STORAGE_LINODE='<bucket_name>'
PATH_STORAGE_BACKBLAZE='<bucket_name>'

PATH_LOCAL_BASEDIR='/tmp'

PATH_LOCAL_UPLOAD_AWS="${PATH_LOCAL_BASEDIR}/backup-upload"
PATH_LOCAL_UPLOAD_LINODE="${PATH_LOCAL_BASEDIR}/backup-upload"
PATH_LOCAL_UPLOAD_BACKBLAZE="${PATH_LOCAL_BASEDIR}/backup-upload"

PATH_LOCAL_DOWNLOAD_AWS="${PATH_LOCAL_BASEDIR}/backup-download"
PATH_LOCAL_DOWNLOAD_LINODE="${PATH_LOCAL_BASEDIR}/backup-download"
PATH_LOCAL_DOWNLOAD_BACKBLAZE="${PATH_LOCAL_BASEDIR}/backup-download"
```

Encrypt files in directory `~/backup` and upload them to the Linode object storage. The backup dictionary file will be saved in file `~/backup.log`.

Encrypt and upload files with two parallel processes:
```bash
backup_encrypt_upload_parallel.sh -m linode -l ~/backup.log ~/backup
```
Alternatively, encrypt and then upload files sequentially:
```bash
backup_encrypt_upload.sh -m linode -l ~/backup.log ~/backup
```
Browse contents of backup described by the dictionary file `backup.log`:
```bash
backup_browse.sh -m linode -l ~/backup.log
```
Fetch all object keys from remote storage and look them up in local dictionary files located in `~/tmp/dictionary-log-files`:
```bash
backup_browse_reverse.sh -m linode ~/tmp/dictionary-log-files/
```
Download backup described by the dictionary file `backup.log`:
```bash
backup_download.sh -m linode -l ~/backup.log
```
Delete from object storage the backup described by the dictionary file `backup.log`:
```bash
backup_delete.sh -m linode ~/backup.log
```

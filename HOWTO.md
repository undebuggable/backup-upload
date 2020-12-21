Prerequisities/Requirements
------------

Setup the CLI clients for the cloud service provider.

### Amazon S3

[Setup the CLI client for AWS S3.](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html)

Test the CLI client and the presence of backup bucket:
```bash
aws --profile <aws_cli_profile> s3 ls
```

### Linode object storage

[Setup the CLI client for Linode object storage.](https://www.linode.com/docs/guides/how-to-use-object-storage/) The `s3cmd` client is also needed in addition to the Linode's `linode-cli`. The `s3cmd` client will transparently take care of Linode's limit of 5GB per one object,

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

The toolset provide *create*, *read*, and *delete* operations on the backup:
- create - `backup_encrypt_upload.sh`, `backup_encrypt_upload_parallel.sh`
- read - `backup_download.sh`
- delete - `backup_delete.sh`
Test the  existence of backup with `backup_test.sh`.

Encrypt files in a directory specified with parameter `-b` and upload them to object storage on Linode. The backup dictionary file will be saved in file specified by the parameter `-l`.

The encryption and uploading will be handled by two parallel processes:
```bash
backup_encrypt_upload_parallel.sh -m linode -b ~/backup -l ~/backup.log
```
Encrypt and then upload the files sequentially:
```bash
backup_encrypt_upload_parallel.sh -m linode -b ~/backup -l ~/backup.log
```
Test the existence of backup:
```bash
backup_test.sh -m linode -l ~/backup.log
```
Download the backup described by the dictionary file:
```bash
backup_download.sh -m linode -l ~/backup.log
```
Delete the backup from the object storage:
```bash
`backup_delete.sh` -m linode -l ~/backup.log
```

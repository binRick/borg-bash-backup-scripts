#!/bin/bash
set -ex

[[ -f "$ENV_FILE" ]] && source $ENV_FILE
[[ "$BORG_PASSPHRASE" == "" ]] && echo Invalid BORG_PASSPHRASE && exit 1
[[ "$BORG_REPO" == "" ]] && echo Invalid BORG_REPO && exit 1
[[ "$REMOTE_BACKUP_SERVER" == "" ]] && echo Invalid REMOTE_BACKUP_SERVER && exit 1
[[ "$REMOTE_BACKUP_SERVER_PATH" == "" ]] && echo Invalid REMOTE_BACKUP_SERVER_PATH && exit 1

GITLAB_BACKUPS_DIR=/var/log/gitlabBackups

[[ ! -d $GITLAB_BACKUPS_DIR ]] && mkdir -p $GITLAB_BACKUPS_DIR

if [[ ! -d $BORG_REPO ]]; then
	borg init -e repokey
fi

echo -e "Creating Gitlab Backup"
gitlab-rake gitlab:backup:create 2>&1 > $GITLAB_BACKUPS_DIR/create_$(date +%s).txt
echo -e "   OK"

cd /backup

borg info
borg create --stats -v -x --list ::$(date +%s) *_gitlab_backup.tar /etc/gitlab
borg info


ssh root@$REMOTE_BACKUP_SERVER mkdir -p $REMOTE_BACKUP_SERVER_PATH

time command rsync -ar /backup/*_gitlab_backup.tar root@$REMOTE_BACKUP_SERVER:${REMOTE_BACKUP_SERVER_PATH}/. --progress 2>&1 > $GITLAB_BACKUPS_DIR/sync_${REMOTE_BACKUP_SERVER}_$(date +%s).txt && \

for oldFile in $(find /backup/*_gitlab_backup.tar -mtime +20); do
    echo "Removing file $oldFile"
    rm -f $oldFile
done


command rm -f /backup/*_gitlab_backup.tar

exit

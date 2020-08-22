#!/bin/bash
cd $( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
set -o errexit          # Exit on most errors (see the manual)
set -o errtrace         # Make sure any error trap is inherited
source .ansi.sh

[[ -f "$ENV_FILE" ]] && source $ENV_FILE
[[ "$BORG_REPO_SERVER" == "" ]] && echo Invalid BORG_REPO_SERVER && exit 1
[[ "$BORG_REPO" == "" ]] && echo Invalid BORG_REPO && exit 1
[[ "$BW_LIMIT_KBPS" == "" ]] && export BW_LIMIT_KBPS=300

set -o nounset          # Disallow expansion of unset variables
set -o pipefail         # Use last non-zero exit code in a pipeline

ACQUIRE_FILESYSTEMS_TO_BACKUP_CMD="command mount| command egrep ' ext4 | xfs '|cut -d' ' -f3"
FORWARDED_HOST=127.0.0.1

rand_port(){
    echo -e "$((10000 + RANDOM % 65000))"
}
rand_host_octet(){
    echo -e "$((1 + RANDOM % 255))"
}
rand_local_host(){
    echo "127.$(rand_host_octet).$(rand_host_octet).$(rand_host_octet)"
}
get_local_borg_path(){
    command -v borg
}
LOCAL_BORG="$(get_local_borg_path)"
ADDITIONAL_FILESYSTEMS_TO_BACKUP="/etc"


for REMOTE_HOST in $REMOTE_HOSTS_TO_BACKUP; do
    FORWARDED_PORT="$(rand_port)"
    remote_ssh_cmd(){
        cmd="command ssh -q $REMOTE_USER@$REMOTE_HOST '$1'"
        eval $cmd
    }
    get_remote_filesystems(){
        remote_ssh_cmd "'$ACQUIRE_FILESYSTEMS_TO_BACKUP_CMD'"
    }
    get_remote_borg_path(){
        remote_ssh_cmd "command -v borg"
    }
    get_remote_hostname(){
        remote_ssh_cmd "command hostname -f"
    }

    REMOTE_HOSTNAME="$(get_remote_hostname)"
    LOCAL_BACKUP_STORAGE_FOLDER="$LOCAL_FOLDER_TO_STORE_BORG_REPOS/${REMOTE_HOSTNAME}.borg"
    local_borg_init(){
        cmd="BORG_PASSPHRASE='$BORG_PASSPHRASE' $LOCAL_BORG init -e repokey '$LOCAL_BACKUP_STORAGE_FOLDER'"
        eval $cmd
    }
    [[ ! -d "$LOCAL_BACKUP_STORAGE_FOLDER" ]] && local_borg_init
    REMOTE_BORG="$(get_remote_borg_path)"

    for REMOTE_FILESYSTEM_TO_BACKUP in $(get_remote_filesystems) $ADDITIONAL_FILESYSTEMS_TO_BACKUP; do
        echo -e backing up $REMOTE_FILESYSTEM_TO_BACKUP
        LOCAL_BACKUP_REPO_NAME="${REMOTE_HOSTNAME}-$(echo -e "$REMOTE_FILESYSTEM_TO_BACKUP"|tr '/' '_')-$(date +%Y-%M-%d-1)"


        cmd="time command ssh -R $FORWARDED_PORT:127.0.0.1:22 $REMOTE_USER@$REMOTE_HOST \"time BORG_RELOCATED_REPO_ACCESS_IS_OK=yes BORG_PASSPHRASE='$BORG_PASSPHRASE' BORG_REPO='ssh://$LOCAL_USER@$FORWARDED_HOST:$FORWARDED_PORT${LOCAL_BACKUP_STORAGE_FOLDER}' BORG_REMOTE_PATH='$LOCAL_BORG' '$REMOTE_BORG' create --rsh 'ssh -ostricthostkeychecking=no -ouserknownhostsfile=/dev/null -q' --stats --one-file-system --numeric-owner -v -x --progress --lock-wait 10 --remote-ratelimit '$BW_LIMIT_KBPS' ::$LOCAL_BACKUP_REPO_NAME $REMOTE_FILESYSTEM_TO_BACKUP\""

        echo -e "\n\n"
        ansi --green "        $cmd"
        echo -e "\n"
        ansi --green "        Bandwidth Limit = $BW_LIMIT_KBPS KB/s"
        echo -e "\n\n"
        set +e
        eval $cmd
        exit_code=$?
        set -e
    done
done

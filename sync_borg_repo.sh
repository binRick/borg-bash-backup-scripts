#!/bin/bash
cd $( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
set -o errexit          # Exit on most errors (see the manual)
set -o errtrace         # Make sure any error trap is inherited

[[ -f "$ENV_FILE" ]] && source $ENV_FILE
[[ "$BORG_REPO_SERVER" == "" ]] && echo Invalid BORG_REPO_SERVER && exit 1
[[ "$BORG_REPO" == "" ]] && echo Invalid BORG_REPO && exit 1



[[ "$BW_LIMIT_KBPS" == "" ]] && export BW_LIMIT_KBPS=300

set -o nounset          # Disallow expansion of unset variables
set -o pipefail         # Use last non-zero exit code in a pipeline

LOCAL_STORAGE_DIR=~/Desktop/gitlab/ARCHIVE_BORG/.
if [[ ! -d "$LOCAL_STORAGE_DIR" ]]; then mkdir -p $LOCAL_STORAGE_DIR; fi

_borg=$(command -v borg)
_rsync=$(command -v rsync)

RSYNC_ARGS="--bwlimit=$BW_LIMIT_KBPS -ar --progress --partial"



#source functions.sh
[[ ! -f ~/.ansi ]] && wget -q4 https://raw.githubusercontent.com/fidian/ansi/master/ansi -O ~/.ansi && chmod 600 ~/.ansi
source ~/.ansi



cmd="time command $_rsync $RSYNC_ARGS root@${BORG_REPO_SERVER}:${BORG_REPO} $LOCAL_STORAGE_DIR/. --delete"
echo -e "\n\n"
ansi --green "        $cmd"
echo -e "\n"
ansi --green "        Bandwidth Limit = $BW_LIMIT_KBPS KB/s"
echo -e "\n\n"
eval $cmd

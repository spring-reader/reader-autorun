#!/bin/bash

WORK_DIR=`cd $(dirname $0); pwd;`

export CHECK_UPDATE_DAYS=$((1 * 24 * 60 * 60))  # 1days
MAIN_SELF=$$

source ${WORK_DIR}/proxy.sh

trap 'kill $CHECK_UPDATE_PID $READER_PID' EXIT SIGKILL


update_self()
{
	git fetch origin main
	[[ $? != 0 ]] && return -1

	local git_head_commit_old=$(git rev-parse HEAD)
	local git_head_commit_new=$(git log remotes/origin/main -n1 --pretty=oneline | awk '{print $1}')
	[[ "$git_head_commit_old" = "$git_head_commit_new" ]] && return 0

	git checkout .
	git reset --hard origin/main

	return 1
}

check_update()
{
	local check_interval=$1
	local pid=$2

	while true ; do
		local ret=0
		pushd $WORK_DIR &> /dev/null
		update_self
		ret=$?
		popd &> /dev/null

		if [[ $ret == 1 ]]; then
			kill $pid
		else
			sleep $check_interval
		fi
	done
}


check_update $CHECK_UPDATE_DAYS $MAIN_SELF &
CHECK_UPDATE_PID=$!

sleep 5

bash ${WORK_DIR}/reader.sh  $@ &
READER_PID=$!

wait $READER_PID


#!/bin/bash

WORK_DIR=`cd $(dirname $0); pwd;`
READER_PID=${READER_PID:-$1}
TIMEOUT_DAYS=$((1 * 24 * 60 * 60))  # 1days
BACKUP_DAYS=7
GIT_REPO="https://github.com/spring-reader/reader-data-backup"
STORAGE_NAME="storage"
STORAGE_DIR="${WORK_DIR}/${STORAGE_NAME}"
STORAGE_TAR="${STORAGE_NAME}.tar.gz"
CRE_TAR=".gitconf.tar.gz"
BACKUP_DIR="${WORK_DIR}/reader-data-backup"
USER_NAME=$(id -u -n)
NODE_NAME=$(uname -n)
BRANCH_NAME="${NODE_NAME}-${USER_NAME}"

SLEEP_PID=
trap 'kill -9 $READER_PID $SLEEP_PID;' EXIT SIGKILL

back_init() {
	[[ -e $BACKUP_DIR ]] && rm -rf $BACKUP_DIR
	git clone -b $BRANCH_NAME --depth 1 $GIT_REPO
	if [[ $? = 0 ]]; then
		return
	fi
	git clone -b main --depth 1 $GIT_REPO
	[[ $? = 0 ]]  || exit 111
}

auto_restore() {
	if [[ -e $STORAGE_DIR ]]; then
		return
	fi

	pushd $BACKUP_DIR &> /dev/null
	[[ $? = 0 ]]  || exit 112
		git checkout .
		git pull
		[[ $? != 0 ]] && exit 123

		git checkout $BRANCH_NAME &> /dev/null
		if [[ $? != 0 ]]; then
			git checkout main
			git pull
			git checkout -b $BRANCH_NAME
			cp .gitconfig .git/config
			tar -xf $CRE_TAR
			git push --set-upstream origin $BRANCH_NAME
			rm -f .git-credentials
		fi
		tar -xf $STORAGE_TAR
		mv $STORAGE_NAME $STORAGE_DIR
	popd &> /dev/null
}

auto_backup() {
	pushd $BACKUP_DIR &> /dev/null
	[[ $? = 0 ]]  || exit 113

	local recent_log=`git log --after="${BACKUP_DAYS}days" --oneline`
	if [[ -n $recent_log ]]; then
		popd &> /dev/null
		return
	fi

	git checkout .
	git pull
	git checkout $BRANCH_NAME &> /dev/null
	if [[ $? != 0 ]]; then
		git checkout -b $BRANCH_NAME
	fi

	cp .gitconfig .git/config
	tar -xf $CRE_TAR
	rm -f $STORAGE_TAR

	mkdir -p ./${STORAGE_NAME}/data
	# cp -rf ${WORK_DIR}/${STORAGE_NAME}/data  ./${STORAGE_NAME}/
	local user=
	# local book=
	for user in $(ls ${WORK_DIR}/${STORAGE_NAME}/data); do
		local old_dir_user="${WORK_DIR}/${STORAGE_NAME}/data/$user"
		local new_dir_user="./${STORAGE_NAME}/data/$user"
		if [[ -d "$old_dir_user" ]]; then
			mkdir -p $new_dir_user
			cp $old_dir_user/*.json $new_dir_user
		else
			cp $old_dir_user $new_dir_user
		fi
		# for book in $(ls -F ./${STORAGE_NAME}/data/$user | grep '/$'); do
		# 	[[ "$book" =~ "webdav" ]] && continue
		# 	rm -rf ./${STORAGE_NAME}/data/$user/$book
		# done
	done
	tar -czf $STORAGE_TAR $STORAGE_NAME
	rm -rf $STORAGE_DIR
	mv $STORAGE_NAME $STORAGE_DIR

	git add $STORAGE_TAR
	git commit -s -m "backup:${BRANCH_NAME}_$(date +%Z-%Y/%m/%d-%H:%M:%S)"
	git push --set-upstream origin $BRANCH_NAME

	rm -f .git-credentials
	popd &> /dev/null
}

cd $WORK_DIR
back_init
auto_restore

while true; do
	if [[ -e $STORAGE_DIR ]]; then
		auto_backup
	else
		auto_restore
	fi

	sleep $(($TIMEOUT_DAYS + $RANDOM)) &
	SLEEP_PID=$!

	wait
done

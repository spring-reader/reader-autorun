#!/bin/bash
#
set -x

SECURE_KEY=${SECURE_KEY:-1}
SERVER_PORT=${1:-8080}
WORK_DIR=`cd $(dirname $0); pwd;`
WORK_QUIET=${2:-1}

# DOCKER_COMPOSE="docker-compose"
BACKUP_PID=
JAVA_PID=
READER_JAR_STATIC_VERSION="3.2.6"

# locale-gen en_US.UTF-8
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8

JAVA_VERSION=21
case $(arch) in
	x86_64)
		JAVA_TAR="jdk-${JAVA_VERSION}_linux-x64_bin.tar.gz"
		JQ_NAME=jq-linux-amd64
		;;
	arm64|aarch64)
		JAVA_TAR="jdk-${JAVA_VERSION}_linux-aarch64_bin.tar.gz"
		JQ_NAME=jq-linux-arm64
		;;
	*)
		exit -1
		;;
esac

trap 'kill $BACKUP_PID $JAVA_PID' EXIT SIGKILL

install_java() {
	java -h &> /dev/null
	if [[ $? == 0 ]] ; then
		return
	fi


	local java_dir=$(basename jdk-${JAVA_VERSION}.*)
	if [[ ! -e "$java_dir" ]]; then
		rm -rf jdk
		wget https://download.oracle.com/java/${JAVA_VERSION}/latest/$JAVA_TAR &> /dev/null
		[[ $? != 0 ]] && (rm -f $JAVA_TAR; exit 111)
		tar -xf $JAVA_TAR
		java_dir=$(basename jdk-${JAVA_VERSION}.*)
		ln -s $java_dir jdk
		rm -f $JAVA_TAR
	fi
	[[ -e jdk ]] || ln -s $java_dir jdk

	export JAVA_OPTS="-Dsun.jnu.encoding=UTF-8 -Dfile.encoding=UTF-8"
	export JAVA_HOME=$(pwd)/jdk
	export JRE_HOME=${JAVA_HOME}/jre
	export CLASSPATH=.:${JAVA_HOME}/lib:${JRE_HOME}/lib
	export PATH=.:${JAVA_HOME}/bin:$PATH
}

install_jq() {
	jq -h &> /dev/null
	if [[ $? == 0 ]] ; then
		return
	fi

	if [[ ! -e $JQ_NAME ]]; then
		wget https://github.com/jqlang/jq/releases/download/jq-1.7/$JQ_NAME &> /dev/null
		[[ $? != 0 ]] && (rm -f $JQ_NAME; exit 222)
		chmod +x ./$JQ_NAME
		[[ -e jq ]] && rm -f jq
		ln -s $JQ_NAME jq
	fi

	export PATH=.:$(pwd):$PATH
}

docker_update() {
	docker-compose pull && docker-compose up -d
}

install_docker_compose() {
	docker -h &> /dev/null
	if [[ $? != 0 ]] ; then
		echo "ERR: docker isn't installed."
		exit 255
	fi

	docker-compose -h &> /dev/null
	if [[ $? = 0 ]]; then
		return
	fi

	if [[ ! -e docker-compose ]]; then
		wget https://github.com/docker/compose/releases/download/v2.20.2/docker-compose-linux-x86_64 &> /dev/null

		chmod +x ./docker-compose-linux-x86_64
		ln -s docker-compose-linux-x86_64 docker-compose
	fi

	export PATH=.:$(pwd):$PATH
}


install_reader_in_docker() {
	DOCKER_YAML="docker-compose.yml"

	docker-compose stop

	[[ -e $DOCKER_YAML ]] && rm -f $DOCKER_YAML
	wget https://ghproxy.com/https://raw.githubusercontent.com/hectorqin/reader/master/$DOCKER_YAML

	# mkdir -p logs storage

	local file_dir=$(pwd)
	local remotePort=$SERVER_PORT
	local adminPassword="zadminpwd"
	local user_count=3
	local register_code="guanliyuanzuishuai"

	sed -i "/\/logs/c\        - ${file_dir}\/logs:\/logs" $DOCKER_YAML
	sed -i "/\/storage/c\        - ${file_dir}\/storage:\/storage" $DOCKER_YAML
	sed -i "s/4396/${remotePort}/" $DOCKER_YAML
	# sed -i "s/openj9-latest/${dockerImages}/" $DOCKER_YAML
	# 多用户
	# sed -i "s/READER_APP_SECURE\=true/READER_APP_SECURE\=${isMultiUser}/" $DOCKER_YAML
	sed -i "/READER_APP_USERLIMIT/c\        - READER_APP_USERLIMIT=${user_count}" $DOCKER_YAML
	sed -i "s/adminpwd/${adminPassword}/" $DOCKER_YAML
	sed -i "s/registercode/${register_code}/" $DOCKER_YAML


	# 启动 docker-compose
	docker-compose up -d

	# 停止 docker-compose
	# docker-compose stop
}

reader_jar_get_latest() {

	install_jq

	local file_name=$(basename reader*.jar)
	# declare -r file_name
	local tag2=$(wget -qO- -t1 -T2 "https://api.github.com/repos/hectorqin/reader/releases/latest" | grep "tag_name" | head -n 1 | awk -F "v" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')
	([[ $? != 0 ]] || [[ -z "$tag2" ]]) && echo "WARN: tag2 get failed!" && return -1

	[[ "${file_name}" =~ "${tag2}" ]] && return 0

	local tag1=$(wget -qO- -t1 -T2 "https://api.github.com/repos/hectorqin/reader/releases/latest" | jq -r '.tag_name')
	local new_file_name="reader-pro-${tag2}.jar"
	wget https://github.com/hectorqin/reader/releases/download/${tag1}/$new_file_name &> /dev/null
	[[ $? != 0 ]] && (rm -f $new_file_name; echo "WARN: wget failed." ) && return -1

	[[ "${file_name}" != "reader*.jar" ]] && (rm -rf ${file_name}*; echo "WARN: jar get latest failed.") && return -1
}

reader_jar_get_static() {
	local file_name=$(basename reader*.jar)
	[[ "${file_name}" =~ "${READER_JAR_STATIC_VERSION}" ]] && return 0

	local static_ver="reader-pro-${READER_JAR_STATIC_VERSION}.jar"
	wget https://github.com/hectorqin/reader/releases/download/v${READER_JAR_STATIC_VERSION}/$static_ver
	[[ $? != 0 ]] && (rm -f $static_ver; echo "WARN: wget failed.") && return -1
}

reader_jar_download() {
	reader_jar_get_latest
	[[ -e $(basename reader*.jar) ]] || reader_jar_get_static
	if [[ ! -e $(basename reader*.jar) ]]; then
		echo "ERR: jar get failed."
		exit 255
	fi
}

install_in_host() {

	killall java
	install_java

	reader_jar_download

	RUN_ARGS=""
	local inviteCode="guanliyuanzuishuai"
	local adminPassword="zadminpwd"
	local userLimit=3
	if [[ -n "${SECURE_KEY}" ]]; then
	    RUN_ARGS="--reader.app.secure=true --reader.app.secureKey=${adminPassword} \
		      --reader.app.inviteCode=${inviteCode} --reader.app.userLimit=$userLimit "
	fi

	if [[ $WORK_QUIET = 1 ]]; then
		java -jar reader*.jar --reader.server.port=$SERVER_PORT $RUN_ARGS  &>/dev/null  &
		JAVA_PID=$!
	else
		java -jar reader*.jar --reader.server.port=$SERVER_PORT $RUN_ARGS &
		JAVA_PID=$!
	fi

	wait
	exit 255
}

install_in_docker() {
	install_docker_compose
	install_reader_in_docker
}

auto_backup() {
	git checkout .
	git checkout main
	git pull
	bash $WORK_DIR/backup.sh &
	BACKUP_PID=$!

	# wait data restore
	while [[ ! -e "${WORK_DIR}/storage" ]]; do
		sleep 1
	done
}


cd $WORK_DIR

auto_backup

if [[ ! -n "$3" ]]; then
	install_in_host
else
	install_in_docker
fi

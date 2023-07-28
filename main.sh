#!/bin/bash
#
set -x

SECURE_KEY=${SECURE_KEY:-1}

SERVER_PORT=$1

WORK_DIR="$(pwd)/$(dirname $0)"
DOCKER_COMPOSE="${WORK_DIR}/docker-compose"
READER_CONFIG="${WORK_DIR}/reader-assets/reader.css"

install_java() {
	java --version &> /dev/null
	if [[ $? == 0 ]] ; then
		return
	fi

	if [[ ! -e jdk ]]; then
		wget https://download.oracle.com/java/20/latest/jdk-20_linux-x64_bin.tar.gz
		tar -xf jdk-20_linux-x64_bin.tar.gz
		ln -s jdk-20.0.2 jdk
	fi

	export JAVA_HOME=$(pwd)/jdk
	export JRE_HOME=${JAVA_HOME}/jre
	export CLASSPATH=.:${JAVA_HOME}/lib:${JRE_HOME}/lib
	export PATH=.:${JAVA_HOME}/bin:$PATH
}

install_docker_compose() {
	docker --version
	if [[ $? != 0 ]] ; then
		echo "docker isn't installed."
		exit 255
	fi

	if [[ -e docker-compose ]]; then
		return
	fi

	wget https://github.com/docker/compose/releases/download/v2.20.2/docker-compose-linux-x86_64

	chmod +x ./docker-compose-linux-x86_64
	ln -s docker-compose-linux-x86_64 docker-compose
}


install_reader_in_docker() {
	[[ -e docker-compose.yaml ]] && rm -f docker-compose.yaml
	wget https://ghproxy.com/https://raw.githubusercontent.com/hectorqin/reader/master/docker-compose.yaml

	# mkdir -p logs storage

	file_dir=$(pwd)
	remotePort=4396
	adminPassword="zadminpwd"
	user_count=3
	register_code="guanliyuanzuishuai"
	sed -i "s#\/home\/reader#${file_dir}#" docker-compose.yaml
	sed -i "s/4396/${remotePort}/" docker-compose.yaml
	# sed -i "s/openj9-latest/${dockerImages}/" docker-compose.yaml
	# 多用户
	# sed -i "s/READER_APP_SECURE\=true/READER_APP_SECURE\=${isMultiUser}/" docker-compose.yaml
	sed -i "s/READER_APP_USERLIMIT=50/READER_APP_USERLIMIT=${user_count}/" docker-compose.yaml
	sed -i "s/adminpwd/${adminPassword}/" docker-compose.yaml
	sed -i "s/registercode/${register_code}/" docker-compose.yaml


	# 启动 docker-compose
	$DOCKER_COMPOSE up -d

	# 停止 docker-compose
	$DOCKER_COMPOSE stop
}

install_in_host() {

	killall java

	install_java

	FileName=$(basename reader*.jar)
	# declare -r FileName
	tag2=$(wget -qO- -t1 -T2 "https://api.github.com/repos/hectorqin/reader/releases/latest" | grep "tag_name" | head -n 1 | awk -F "v" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')

	if [[ ! "${FileName}" =~ "${tag2}" ]] && [ "${tag2}" != "" ]; then
	    tag1=$(wget -qO- -t1 -T2 "https://api.github.com/repos/hectorqin/reader/releases/latest" | jq -r '.tag_name')
	    wget https://github.com/hectorqin/reader/releases/download/${tag1}/reader-pro-${tag2}.jar
	    EXIT_CODE=$?
	    if [ "${FileName}" != reader\*.jar ] && [ "${EXIT_CODE}" -eq 0 ]; then
		rm -rf ${FileName}
	    fi
	fi

	# local parent_dir=$(dirname $WORK_DIR)
	# local storage_dir=${parent_dir}/storage
	# # sed -i "/storagePath:/c\    storagePath:${parent_dir}" $READER_CONFIG
	# mkdir -p $storage_dir
	# ln -s $storage_dir storage

	local inviteCode="guanliyuanzuishuai"
	if [ "${SECURE_KEY}" != "" ]; then
	    java -jar reader*.jar --reader.app.secure=true --reader.app.secureKey=${SECURE_KEY} \
		    		  --reader.app.inviteCode=${inviteCode} --reader.server.port=$SERVER_PORT
				  # --reader.app.storagePath=${parent_dir}/storage
	else
	    java -jar reader*.jar --reader.server.port=$SERVER_PORT
				  # --reader.app.storagePath=${parent_dir}/storage
	fi
}

install_in_docker() {
	install_docker_compose
	install_reader_in_docker
	$DOCKER_COMPOSE pull && $DOCKER_COMPOSE up -d
}


cd $WORK_DIR

if [[ ! -n "$2" ]]; then
	install_in_host
else
	install_in_docker
fi

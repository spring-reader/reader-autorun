#!/bin/bash

#proxy_ip=
#proxy_port=
#static_version=
CONF_READER_FILE="${WORK_DIR}/c_config.conf"
if [[ ! -e $CONF_READER_FILE ]]; then
	return 0
fi

source $CONF_READER_FILE
if [[ -n $proxy_ip ]] && [[ -n $proxy_port ]]; then
	export http_proxy="http://${proxy_ip}:${proxy_port}"
	export https_proxy="http://${proxy_ip}:${proxy_port}"
fi

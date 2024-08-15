#!/bin/bash

#proxy_ip=
#proxy_port=
CONF_READER_PROXY="${WORK_DIR}/c_proxy.conf"
if [[ -e $CONF_READER_PROXY ]]; then
	source $CONF_READER_PROXY
	export http_proxy="http://${proxy_ip}:${proxy_port}"
	export https_proxy="http://${proxy_ip}:${proxy_port}"
fi


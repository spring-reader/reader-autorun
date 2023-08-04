FROM ubuntu:22.04
# FROM python:3.9.0-buster

WORKDIR /app

# RUN /bin/sh -c "apt-get update && apt-get install -y git wget openjdk-11-jdk jq"
RUN /bin/sh -c "apt-get update && apt-get install -y git wget  jq"
RUN /bin/sh -c "apt-get install -y locales"
# RUN /bin/sh -c "apt-get install language-pack-zh-hans language-pack-zh-hans-base language-pack-gnome-zh-hans language-pack-gnome-zh-hans-base"

# RUN /bin/sh -c 'echo "export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64" >> /root/.bashrc'
# RUN /bin/sh -c 'echo "export PATH=$JAVA_HOME/bin:$PATH" >> /root/.bashrc'
# RUN /bin/sh -c 'echo "export CLASSPATH=.:$JAVA_HOME/lib/dt.jar:$JAVA_HOME/lib/tools.jar" >> /root/.bashrc'

RUN /bin/sh -c 'locale-gen zh_CN.UTF-8'
RUN /bin/sh -c 'dpkg-reconfigure locales'
RUN echo 'LANG="en_US.UTF-8"' >> /etc/default/locale
RUN echo 'LANGUAGE="en_US:en"' >> /etc/default/locale

RUN git clone -b main https://github.com/spring-reader/reader-autorun.git

ENV TZ=Asia/Shanghai
EXPOSE 8080
CMD /bin/bash ./reader-autorun/main.sh 8080 0


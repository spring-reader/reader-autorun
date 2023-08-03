FROM hectorqin/remote-webview

# CMD ["/bin/bash"]
ENV TZ=Asia/Shanghai
ENV PLAYWRIGHT_SKIP_BROWSER_GC=1
WORKDIR /app
# RUN /bin/sh -c apt-get update
RUN /bin/sh -c "apt-get update"
RUN /bin/sh -c "apt-get install -y curl wget gpg &&  \
				   apt-get install -y build-essential &&  \
				   curl -sL https://deb.nodesource.com/setup_18.x | bash - &&  \
				   apt-get install -y nodejs &&  \
				   rm -rf /var/lib/apt/lists/* &&  \
				   PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 npm install &&  \
				   npx playwright install --with-deps webkit &&  \
				   apt-get remove -y curl wget gpg &&  \
				   apt-get autoremove -y &&  \
				   rm -rf /var/lib/apt/lists/* "# buildkit
EXPOSE 8050/tcp
CMD ["node" "index.js"]


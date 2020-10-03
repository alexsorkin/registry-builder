################################################################################################################
FROM alpine as alpine-glibc

LABEL MAINTENANER="Alex Sorkin"

# Install common packages
RUN echo "ipv6" >> /etc/modules && \
    ln -s /var/cache/apk /etc/apk/cache && \
    apk --no-progress update && \
    apk --no-progress upgrade && \
    apk --no-progress add \
      bash openssl linux-pam ca-certificates \
      wget curl bc tar gzip libarchive-tools \
      openssh-client jq make tzdata gettext \
      busybox-extras shadow libsasl libltdl \
      util-linux coreutils binutils findutils grep && \
    export TINI_VERSION=`curl -s https://github.com/krallin/tini/releases/latest|grep -Eo "[[:digit:]]{1,2}"|xargs|sed 's/\ /./g'` && \
    echo "Tini Supervisor Version: ${TINI_VERSION}" && \
    curl -o /bin/tini -fsSL https://github.com/krallin/tini/releases/download/v${TINI_VERSION}/tini-static-amd64 && \
    chmod +x /bin/tini

# Download glibc packages
RUN export GLIBC_RELEASE_URL=https://github.com/sgerrand/alpine-pkg-glibc/releases && \
    curl -sSL -o /etc/apk/keys/sgerrand.rsa.pub https://alpine-pkgs.sgerrand.com/sgerrand.rsa.pub && \
    export GLIBC_MAJOR=`curl -sS ${GLIBC_RELEASE_URL}/latest|grep -Eo "[[:digit:]]{1,2}"|head -2|xargs|sed "s#\ #.#g"` && \
    export GLIBC_MINOR=`curl -sS ${GLIBC_RELEASE_URL}/latest|grep -Eo "[[:digit:]]{1,2}"|head -3|tail -1|xargs echo r|sed "s#\ ##g"` && \
    export GLIBC_VERSION="${GLIBC_MAJOR}-${GLIBC_MINOR}" && \
    echo "Glibc Version: ${GLIBC_VERSION}" && \
    wget -q -O /tmp/glibc.apk ${GLIBC_RELEASE_URL}/download/${GLIBC_VERSION}/glibc-${GLIBC_VERSION}.apk && \
    wget -q -O /tmp/glibc-bin.apk ${GLIBC_RELEASE_URL}/download/${GLIBC_VERSION}/glibc-bin-${GLIBC_VERSION}.apk && \
    wget -q -O /tmp/glibc-i18n.apk ${GLIBC_RELEASE_URL}/download/${GLIBC_VERSION}/glibc-i18n-${GLIBC_VERSION}.apk && \
    apk --no-progress add /tmp/glibc.apk /tmp/glibc-bin.apk /tmp/glibc-i18n.apk && \
    rm -rf /tmp/glibc.apk /tmp/glibc-bin.apk /tmp/glibc-i18n.apk

ENTRYPOINT [ "/bin/tini", "--" ]

################################################################################################################
FROM alpine-glibc as blueocean-slave-glibc-python

# Python
RUN \
    echo "ipv6" >> /etc/modules && \
    ln -s /var/cache/apk /etc/apk/cache && \
    apk --no-progress update && \
    apk --no-progress add \
      openssl ca-certificates \
      shadow libsasl libltdl  \
      python3 python3-dev py3-pip libxml2 libxslt && \
    pip3 install --upgrade pip wheel

################################################################################################################
FROM blueocean-slave-glibc-python as blueocean-slave-glibc-ansible

# Ansible
RUN \
    apk --no-progress add \
      sudo sshpass openssh-client rsync libxml2 libxslt \
      git git-svn git-subtree bind perl-git subversion && \
    apk --no-progress add --virtual build-dependencies \
      build-base libffi-dev openssl-dev \
      linux-headers libtool groff icu-dev libxml2-dev libxslt-dev && \
    pip3 install --upgrade pip wheel && \
    pip3 install --upgrade cffi jmespath lxml && \
    pip3 install ansible-runner ansible-runner-http \
      ansible openshift pycrypto pywinrm && \
    apk del build-dependencies  && \
    rm -rf /etc/apk/cache && \
    rm -rf /var/cache/apk && \
    ln -sf /usr/bin/python3 /usr/bin/python

RUN \
    mkdir -p /etc/ansible && \
    echo "localhost ansible_connection=local" > /etc/ansible/hosts && \
    echo '[defaults]' > /etc/ansible/ansible.cfg && \
    echo 'library = /usr/share/ansible/openshift' >> /etc/ansible/ansible.cfg && \
    mkdir -p /usr/share/ansible/openshift

COPY --from=docker.bintray.io/jfrog/jfrog-cli-go:latest /usr/local/bin/jfrog /usr/local/bin/jfrog

COPY . /builder

WORKDIR /builder
RUN \
    cp -rf ./entrypoint.sh /entrypoint.sh && \
    chmod 755 /entrypoint.sh

ENTRYPOINT [ "/bin/tini", "--", "/entrypoint.sh"]

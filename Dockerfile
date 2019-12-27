#-------------------------------------------------------------------------------------------------------------
# Licensed under the MIT License.
#-------------------------------------------------------------------------------------------------------------

# centos image as a base
FROM centos:centos7

# Avoid warnings by switching to noninteractive
#ENV DEBIAN_FRONTEND=noninteractive


# This Dockerfile adds a non-root 'vscode' user with sudo access. However, for Linux,
# this user's GID/UID must match your local user UID/GID to avoid permission issues
# with bind mounts. Update USER_UID / USER_GID if yours is not 1000. See
# https://aka.ms/vscode-remote/containers/non-root-user for details.
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID

# Proxy設定
ARG PROXY=''
ARG no_proxy='127.0.0.1,localhost,192.168.99.100,192.168.99.101,192.168.99.102,192.168.99.103,192.168.99.104,192.168.99.105,172.17.0.1'

ENV JAVA_HOME=/usr/lib/jvm/adoptopenjdk-8-hotspot

# 自己証明が必要な場合はここで組み込む
ADD /etc/ssl/certs/      /etc/ssl/certs/

# Configure apt and install packages
RUN set -x \
    && if [ -n "$PROXY" ]; then echo -e "\n\
        ca_directory = /etc/ssl/certs/ \n\
        http_proxy = $PROXY \n\
        https_proxy = $PROXY \n\
    " >> /etc/wgetrc; fi\
    && yum -y install initscripts MAKEDEV \
    && yum check \
    && yum -y update \
    && yum -y install make gcc gcc-c++ \
    && yum -y install openssh-server passwd \
    && yum -y install net-tools zip unzip \
    #
    # Verify git, process tools installed
    && yum -y install https://centos7.iuscommunity.org/ius-release.rpm \
    && sed -ri 's/^#enabled=1/enabled=0/' /etc/yum.repos.d/ius.repo \
#    && yum -y install perl-Error perl-TermReadKey libsecret \
#    && git --version \
#    && yum -y remove git git-\* \
    && yum -y install git2u --enablerepo=ius \
    && git --version \
#    && yum -y install git --enablerepo=ius --disablerepo=base,epel,extras,updates \
    #
    # Install Docker CE CLI
    && yum install -y yum-utils device-mapper-persistent-data lvm2 \
    && yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo \
    && yum install -y docker-ce-cli \
    #
    # Install kubectl
    #&& curl -sSL -o /usr/local/bin/kubectl https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl \
    #&& chmod +x /usr/local/bin/kubectl \
    #
    # Install Helm
    # && curl -s https://raw.githubusercontent.com/helm/helm/master/scripts/get | bash - \
    #
    # Create a non-root user to use if preferred - see https://aka.ms/vscode-remote/containers/non-root-user.
    && groupadd --gid $USER_GID $USERNAME \
    && useradd -s /bin/bash --uid $USER_UID --gid $USER_GID -m $USERNAME \
    # [Optional] Add sudo support for the non-root user
    && yum install -y sudo \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME \
    #
# Install nodejs 0.10.25
    && curl http://nodejs.org/dist/v0.10.25/node-v0.10.25.tar.gz -o /tmp/node-v0.10.25.tar.gz \
    && tar zxf /tmp/node-v0.10.25.tar.gz -C /tmp \
    && cd /tmp/node-v0.10.25 \
    && ./configure \
    && make \
    && sudo make install \
    #
# Install mongodb2.4.8
    && curl http://downloads.mongodb.org/linux/mongodb-linux-x86_64-2.4.8.tgz -o /tmp/mongodb-linux-x86_64-2.4.8.tgz \
    && tar zxvf /tmp/node-v0.10.25.tar.gz -C /usr/local \
    && ln -s /usr/local/mongodb-linux-x86_64-2.4.8 /usr/local/mongodb \
    && ln -s /usr/local/mongodb/bin/bsondump /usr/local/bin/bsondump \
    && ln -s /usr/local/mongodb/bin/mongo /usr/local/bin/mongo \
    && ln -s /usr/local/mongodb/bin/mongod /usr/local/bin/mongod \
    && ln -s /usr/local/mongodb/bin/mongodump /usr/local/bin/mongodump \
    && ln -s /usr/local/mongodb/bin/mongoexport /usr/local/bin/mongoexport \
    && ln -s /usr/local/mongodb/bin/mongofiles /usr/local/bin/mongofiles \
    && ln -s /usr/local/mongodb/bin/mongoimport /usr/local/bin/mongoimport \
    && ln -s /usr/local/mongodb/bin/mongorestore /usr/local/bin/mongorestore \
    && ln -s /usr/local/mongodb/bin/mongos /usr/local/bin/mongos \
    && ln -s /usr/local/mongodb/bin/mongosniff /usr/local/bin/mongosniff \
    && ln -s /usr/local/mongodb/bin/mongostat /usr/local/bin/mongostat \
    #
    && curl https://github.com/ijonas/dotfiles/raw/master/etc/init.d/mongod -o /etc/init.d/mongod \
    && sudo chmod +x /etc/init.d/mongod \
    #
    && sudo useradd mongodb \
    && sudo mkdir -p /var/lib/mongodb \
    && sudo mkdir -p /var/log/mongodb \
    && sudo chown mongodb.mongodb /var/lib/mongodb \
    && sudo chown mongodb.mongodb /var/log/mongodb \
# 空パスワードの場合は以下をコメントアウト
    && sed -ri 's/^#PermitEmptyPasswords no/PermitEmptyPasswords yes/' /etc/ssh/sshd_config \
    && sed -ri 's/^#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config \
#    && sed -ri 's/^UsePAM yes/UsePAM no/' /etc/ssh/sshd_config \
    && mkdir /var/run/sshd \
# 空パスワードの場合は以下をコメントアウト
    && passwd -d root \
# 任意のパスワードの場合は以下をコメントアウト & パスワードを書き換える
#    && echo "root:root" | chpasswd \
#
    && ssh-keygen -A \
#    && ssh-keygen -t rsa -N "" -f /etc/ssh/ssh_host_rsa_key \
#
    && mkdir $HOME/workspace \
    
# Clean up
    && rm -rf /var/cache/yum/* \
    && yum clean all
# Switch back to dialog for any ad-hoc use of apt-get
ENV DEBIAN_FRONTEND=

EXPOSE 22
ENTRYPOINT [ "/usr/sbin/sshd", "-D" ]

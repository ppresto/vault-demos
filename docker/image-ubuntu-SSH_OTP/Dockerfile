FROM ubuntu:16.04

RUN apt-get update && apt-get install -y \
        wget \
        unzip \
        openssh-server \
        netcat \
        iputils-ping \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN mkdir /var/run/sshd \
    && useradd ubuntu \
    && mkdir -p /home/ubuntu \
    && echo 'ubuntu:ubuntu' |chpasswd \
    && sed -ri 's/^#?ChallengeResponseAuthentication no/ChallengeResponseAuthentication yes/' /etc/ssh/sshd_config \
    && sed -ri 's/^#?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config  \
    && sed -ri 's/^#?UsePAM.*/UsePAM yes/' /etc/ssh/sshd_config \
    && mkdir /root/.ssh

RUN wget https://releases.hashicorp.com/vault-ssh-helper/0.1.4/vault-ssh-helper_0.1.4_linux_amd64.zip \
    && unzip -q vault-ssh-helper_0.1.4_linux_amd64.zip -d /usr/local/bin \
    && chmod 0755 /usr/local/bin/vault-ssh-helper \
    && chown root:root /usr/local/bin/vault-ssh-helper \
    && mkdir -p /etc/vault-ssh-helper.d

RUN wget https://releases.hashicorp.com/vault/1.2.2/vault_1.2.2_linux_amd64.zip \
    && unzip -q vault_1.2.2_linux_amd64.zip -d /usr/local/bin \
    && chmod 0755 /usr/local/bin/vault \
    && chown root:root /usr/local/bin/vault

COPY sshd /etc/pam.d/
COPY config.hcl /etc/vault-ssh-helper.d/

EXPOSE 22

CMD    ["/usr/sbin/sshd", "-D"]

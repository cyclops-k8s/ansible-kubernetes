FROM ubuntu:25.10
RUN printf '#!/bin/sh\nexit 0' > /usr/sbin/policy-rc.d
RUN apt-get update
RUN apt-get install -y \
    systemd \
    systemd-sysv \
    dbus \
    dbus-user-session \
    openssh-server \
    sudo \
    python3

RUN apt install -y libpolkit-agent-1-0 polkitd
# RUN mkdir -p /run/systemd && \
#     mkdir -p /run/dbus && \
#     mkdir -p /run/sshd && \
#     systemctl mask dev-hugepages.mount sys-fs-fuse-connections.mount sys-kernel-config.mount sys-kernel-debug.mount
# RUN printf "systemctl start systemd-logind" >> /etc/profile

RUN systemctl enable systemd-logind && \
    systemctl disable getty@tty1

RUN mkdir -p /run/sshd && \
    useradd -m -s /bin/bash -G sudo ansible && \
    echo 'ansible:ansible' | chpasswd && \
    echo 'ansible ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers && \
    mkdir -p /home/ansible/.ssh && \
    chown -R ansible:ansible /home/ansible/.ssh && \
    chmod 700 /home/ansible/.ssh

ENTRYPOINT ["/sbin/init"]

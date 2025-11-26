
#!/bin/bash
set -e

pip install --user ansible ansible-lint yamllint
ansible-galaxy collection install -r requirements.yml

sudo apt update
sudo apt install -y bind9-dnsutils iputils-ping sshpass vim

echo -n 'ansible' > ~/.password

mkdir -p ~/.ssh
cp -r /home/vscode/.ssh-original/* ~/.ssh/

ssh-keygen -t rsa -b 4096 -f ~/.rsa_key -N ""

echo "

Host *.k8s.local
    User ansible
    StrictHostKeyChecking no
    IdentityFile ~/.rsa_key

" >> ~/.ssh/config

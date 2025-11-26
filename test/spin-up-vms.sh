#!/bin/bash
docker image build -t baseimage -f Dockerfile .
docker compose -f docker-compose.yml up --wait --detach
rm ~/.ssh/known_hosts

sshpass -f ~/.password ssh-copy-id -i ~/.rsa_key ansible@px.k8s.local
sshpass -f ~/.password ssh-copy-id -i ~/.rsa_key ansible@cp1.k8s.local
sshpass -f ~/.password ssh-copy-id -i ~/.rsa_key ansible@cp2.k8s.local
sshpass -f ~/.password ssh-copy-id -i ~/.rsa_key ansible@cp3.k8s.local
sshpass -f ~/.password ssh-copy-id -i ~/.rsa_key ansible@w1.k8s.local
sshpass -f ~/.password ssh-copy-id -i ~/.rsa_key ansible@w2.k8s.local

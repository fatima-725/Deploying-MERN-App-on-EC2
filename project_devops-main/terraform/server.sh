#!/bin/bash
apt-get -y update

#Installing Docker
apt-get -y install ca-certificates curl gnupg unzip
mkdir -m 0755 -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
"$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" |
  sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

apt-get -y update
apt-get -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

systemctl enable docker
systemctl start docker

mkdir deployment_files

cd deployment_files

CURRENT_DIR=$(pwd)

cat >"${CURRENT_DIR}/docker-compose.yml" <<EOL
version: "3"
services:
  frontend:
    image: abdulhannank/frontend:latest
    hostname: fe
    networks:  
      - appnet


  nodebackend: 
    image: abdulhannank/server:latest
    hostname: be
    networks:  
      - appnet


  reverseproxy: 
    image: abdulhannank/proxy:latest
    ports: 
      - "80:80"
    depends_on:
      - nodebackend
      - frontend
    networks:  
      - appnet

networks:
  appnet:
EOL

cd "${CURRENT_DIR}"

docker compose -p "devops_project" pull
docker compose -p "devops_project" up -d

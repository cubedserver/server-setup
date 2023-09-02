#!/bin/bash

: ${DOCKER_NETWORKS:='nginx-proxy,internal'}
: ${DOCKER_COMPOSE_FILE:='docker-compose.yml'}
: ${APP_TEMPLATES:='portainer,mysql,postgres,redis,adminer,phpmyadmin,whoami'}
: ${DEFAULT_WORKDIR:=`pwd`}

function setup_log() {
  echo -e $1
}

for NETWORK_NAME in $(echo $DOCKER_NETWORKS | sed "s/,/ /g"); do
    setup_log "⚡ Creating Docker network ${NETWORK_NAME}"
    docker network ls|grep $NETWORK_NAME > /dev/null || docker network create $NETWORK_NAME
done

docker-compose -f $DOCKER_COMPOSE_FILE up -d

if [[ ! -z $APP_TEMPLATES ]]; then
    for APP in $(echo $APP_TEMPLATES | sed "s/,/ /g"); do
        if [ -d templates/${APP} ]; then

            setup_log "---> ⚡ Starting ${APP} container"
            docker-compose -f templates/${APP}/docker-compose.yml up -d
        else
            setup_log "---> ❌ App ${APP} files not found. Skipping..."
        fi
    done    
fi
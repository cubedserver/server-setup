#!/bin/bash

ENV_TEMPLATE="https://raw.githubusercontent.com/fabioassuncao/setup-vps/master/.env.example"

BOILERPLATE_NGINX_URL="https://github.com/fabioassuncao/docker-boilerplate-nginx-proxy/archive/master.zip"
ORIGINAL_NAME_NGINX=docker-boilerplate-nginx-proxy
DIR_NAME_NGINX=nginx-proxy

BOILERPLATE_TRAEFIK_URL="https://github.com/fabioassuncao/docker-boilerplate-traefik-proxy/archive/master.zip"
ORIGINAL_NAME_TRAEFIK=docker-boilerplate-traefik-proxy
DIR_NAME_TRAEFIK=traefik-proxy

EXAMPLE_DOMAIN=domain.test
EXAMPLE_EMAIL=email@domain.test

if [[ -z $SHOW_LOGS ]]; then
    SHOW_LOGS=true
fi

if [[ -z $DOCKER_COMPOSE_VERSION ]]; then
    DOCKER_COMPOSE_VERSION="1.27.4"
fi

if [[ -z $WORKDIRS ]]; then
    WORKDIRS="apps backups"
fi

if [[ -z $ROOT_WORKDIR ]]; then
    ROOT_WORKDIR="/var"
fi

if [[ -z $TIMEZONE ]]; then
    TIMEZONE=America/Sao_Paulo
fi

# Reverse proxy configuration variables

if [[ -z $INSTALL_PROXY ]]; then
    INSTALL_PROXY=false
fi

if [[ -z $BOILERPLATE ]]; then
    BOILERPLATE=nginx
fi

if [[ -z $DOCKER_NETWORKS ]]; then
    DOCKER_NETWORKS="web internal"
fi

# greet
function greet() {
    # Welcome users
    if $SHOW_LOGS ; then
      echo -e "\n\n"
      echo -e "\e[32m  ____            _        _   _           _     ____       _                \e[39m"
      echo -e "\e[32m | __ )  __ _ ___(_) ___  | | | | ___  ___| |_  / ___|  ___| |_ _   _ _ __   \e[39m"
      echo -e "\e[32m |  _ \ / _\` / __| |/ __| | |_| |/ _ \/ __| __| \___ \ / _ \ __| | | | '_ \  \e[39m"
      echo -e "\e[32m | |_) | (_| \__ \ | (__  |  _  | (_) \__ \ |_   ___) |  __/ |_| |_| | |_) | \e[39m"
      echo -e "\e[32m |____/ \__,_|___/_|\___| |_| |_|\___/|___/\__| |____/ \___|\__|\__,_| .__/  \e[39m"
      echo -e "\e[32m                                                                     |_|     \e[39m"
      echo -e "\n\n"
    fi
}


# Outputs install log line
function setup_log() {
  if $SHOW_LOGS ; then
      echo -e "\033[1;32m$*\033[m"
  fi
}

function wordwrap() {
  if $SHOW_LOGS ; then
    echo -e "\n"
  fi
}

function install_report() {
    echo $* >> install-report.txt
}

function create_docker_network() {
    NETWORK_NAME=$1
    setup_log "⚡ Creating Docker network ${NETWORK_NAME}"
    docker network ls|grep $NETWORK_NAME > /dev/null || docker network create $NETWORK_NAME
}

# Remove images and containers from a previous unsuccessful attempt
function docker_reset() {
  CONTAINERS=$(docker ps -a -q)
  if [[ ! -z $CONTAINERS ]]; then
      docker stop $CONTAINERS
      docker rm $CONTAINERS
      docker system prune -a --force
  fi
}

function setup_proxy() {

  BOILERPLATE=$1

  if [ $BOILERPLATE == "nginx" ]; then
      BOILERPLATE_URL=$BOILERPLATE_NGINX_URL
      ORIGINAL_NAME=$ORIGINAL_NAME_NGINX
      DIR_NAME=$DIR_NAME_NGINX
  else
      BOILERPLATE_URL=$BOILERPLATE_TRAEFIK_URL
      ORIGINAL_NAME=$ORIGINAL_NAME_TRAEFIK
      DIR_NAME=$DIR_NAME_TRAEFIK
  fi

    FILE_ZIPED=${ORIGINAL_NAME}.zip
    WORKDIR=/var/${VENDOR_NAME}/apps/core

    if [ -d $WORKDIR ]; then
      setup_log "🗑️ Deleting previous files from an unsuccessful previous attempt"
      rm -rf $WORKDIR
    fi

    setup_log "📂 Creating working directory ${WORKDIR} for the $BOILERPLATE Proxy"
    mkdir -p $WORKDIR

    PROXY_FULL_PATH=${WORKDIR}/${DIR_NAME}
    
    setup_log "📥 Downloading boilerplate ${BOILERPLATE}"
    wget $BOILERPLATE_URL -O $FILE_ZIPED

    setup_log "🗃️ Extracting files from ${FILE_ZIPED}"
    unzip -q $FILE_ZIPED && rm $FILE_ZIPED && mv ${ORIGINAL_NAME}-master $PROXY_FULL_PATH

    if [[ ! -z $YOUR_EMAIL ]]; then
        setup_log "📧 Overriding ${EXAMPLE_EMAIL} to ${YOUR_EMAIL} email from configuration files"
        find $PROXY_FULL_PATH -type f -exec sed -i "s/$EXAMPLE_EMAIL/$YOUR_EMAIL/g" {} \;
    fi

    if [[ ! -z $YOUR_DOMAIN ]]; then
        setup_log "🌐 Overriding ${EXAMPLE_DOMAIN} to ${YOUR_DOMAIN} domain for configuration files"
        find $PROXY_FULL_PATH -type f -exec sed -i "s/$EXAMPLE_DOMAIN/$YOUR_DOMAIN/g" {} \;
    fi

    for NETWORK_NAME in $DOCKER_NETWORKS; do
        create_docker_network $NETWORK_NAME
    done 

    setup_log "⚡ Starting reverse proxy containers"
    docker-compose -f ${PROXY_FULL_PATH}/docker-compose.yml up -d

    install_report "Services started"
    install_report "--------------------------------------------------------------------------------"
    install_report "${PROXY_FULL_PATH}/docker-compose.yml"


    # Moves the app folder to the working directory root
    if [[ ! -z $ADDITIONAL_APPS ]]; then
        for APP in $ADDITIONAL_APPS; do
            mv ${PROXY_FULL_PATH}/examples/${APP} ${WORKDIR}/${APP}

            setup_log "⚡ Starting ${APP} container"
            docker-compose -f ${WORKDIR}/${APP}/docker-compose.yml up -d
            install_report "${WORKDIR}/${APP}/docker-compose.yml"
        done    
    fi
}

install_report "--------------------------------------------------------------------------------"
install_report "Started in: $(TZ=$TIMEZONE date)"
install_report "--------------------------------------------------------------------------------"

greet

if [ "$(id -u)" != "0" ]; then
   setup_log "❌ Sorry! This script must be run as root." 1>&2
   exit 1
fi

# prompt
setup_log "🚀 This script will run the initial settings on this server."
read -r -p "Type 'Y' to continue or 'n' to cancel: " GO
if [ "$GO" != "Y" ]; then
    setup_log "❌ Aborting." 1>&2
    exit 1
fi

setup_log "🎲 Do you want to use a file of environment variables to go faster?"
read -r -p "Type 'Y' to download and edit the file or 'n' to skip: " USE_ENV_TEMPLATE
if [ $USE_ENV_TEMPLATE == "Y" ]; then
  setup_log "📥 Downloading template"
  curl -fsSL $ENV_TEMPLATE -o .env
  nano .env
fi

# If there is a env file, source it
if [ -f "./.env" ]; then
   source ./.env
fi

# Update timezone
setup_log "🕒 Updating packages and setting the timezone"
apt-get update -qq >/dev/null
timedatectl set-timezone $TIMEZONE

wordwrap

# Set root password
setup_log "🔑 Setting the root password"

if [[ -z $ROOT_PASSWORD ]]; then
  passwd
else
  echo $ROOT_PASSWORD | passwd > /dev/null 2>&1
fi

# Creates SSH key from root if one does not exist
if [ ! -e /root/.ssh/id_rsa ]; then
   setup_log "🔑 Creating SSH Keys"
   ssh-keygen -t rsa
fi

# Create known_hosts file if it doesn't exist
if [ ! -e /root/.ssh/known_hosts ]; then
   setup_log "📄 Creating file known_hosts"
   touch /root/.ssh/known_hosts
fi

# Create authorized_keys file if it doesn't exist
if [ ! -e /root/.ssh/authorized_keys ]; then
  setup_log "📄 Creating file authorized_keys"
  touch /root/.ssh/authorized_keys
fi

wordwrap

# Adds bitbucket.org, gitlab.com, github.com
setup_log "⚪ Adding bitbucket.org to trusted hosts"
ssh-keyscan bitbucket.org >> /root/.ssh/known_hosts

wordwrap

setup_log "⚪ Adding gitlab.com to trusted hosts"
ssh-keyscan gitlab.com >> /root/.ssh/known_hosts

wordwrap

setup_log "⚪ Adding github.com to trusted hosts"
ssh-keyscan github.com >> /root/.ssh/known_hosts

wordwrap

# pedir nome de usuário do novo usuário padrão
if [[ -z $DEPLOYER_USERNAME ]]; then
  read -r -p "👤 Enter a username for the user who will deploy applications (e.g. deployer): " DEPLOYER_USERNAME
  if [ -z $DEPLOYER_USERNAME ]; then
      DEPLOYER_USERNAME=deployer
      setup_log "ℹ️ Using default value ${DEPLOYER_USERNAME}"
  fi
fi

if [[ -z $VENDOR_NAME ]]; then
  read -r -p "🏢 Enter a default folder name where the apps, storage and backups will be (e.g. yourcompany): " VENDOR_NAME
  if [[ -z $VENDOR_NAME ]]; then
      VENDOR_NAME=projects
      setup_log "ℹ️ Using default value ${VENDOR_NAME}"
  fi
fi

wordwrap

# adiciona usuário padrão
setup_log "👤 Creating standard user"
useradd -s /bin/bash -d /home/$DEPLOYER_USERNAME -m -U $DEPLOYER_USERNAME

if [[ -z $DEPLOYER_PASSWORD ]]; then
  passwd $DEPLOYER_USERNAME
else
  echo $DEPLOYER_PASSWORD | passwd $DEPLOYER_USERNAME > /dev/null 2>&1
fi

wordwrap

# copia SSH authorized_keys
setup_log "🗂️ Copying the SSH public key to the home directory of the new default user"
if [ ! -d /home/$DEPLOYER_USERNAME/.ssh ]; then
  mkdir /home/$DEPLOYER_USERNAME/.ssh
fi
cp -r /root/.ssh/* /home/$DEPLOYER_USERNAME/.ssh/
chown -R $DEPLOYER_USERNAME.$DEPLOYER_USERNAME /home/$DEPLOYER_USERNAME/.ssh

wordwrap

# add standard user to sudoers
setup_log "💪 Adding $DEPLOYER_USERNAME to sudoers with full privileges"
echo "$DEPLOYER_USERNAME ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/$DEPLOYER_USERNAME
chmod 0440 /etc/sudoers.d/$DEPLOYER_USERNAME

wordwrap

setup_log "🟢 Installing essential programs (git zip unzip curl wget acl)"
apt-get install -y -qq --no-install-recommends git zip unzip curl wget acl

wordwrap

if [ -x "$(command -v docker)" ]; then
    setup_log "🐳 Docker previously installed! Resetting containers, images and networks."
    docker_reset
else
    setup_log "🐳 Installing docker"
    curl -fsSL get.docker.com -o get-docker.sh && sh get-docker.sh
fi

wordwrap

if [ ! -f /usr/local/bin/docker-compose ]; then
  setup_log "📦 Installing docker-compose"
  curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-Linux-x86_64" -o /usr/local/bin/docker-compose
  chmod +x /usr/local/bin/docker-compose

  wordwrap
fi

setup_log "🟢 Adding user $DEPLOYER_USERNAME to group www-data"
usermod -aG www-data $DEPLOYER_USERNAME

setup_log "🟢 Adding user $DEPLOYER_USERNAME to the docker group"
usermod -aG docker $DEPLOYER_USERNAME

wordwrap

for WORKDIR in $WORKDIRS; do

  WORKDIR_FULL=${ROOT_WORKDIR}/$VENDOR_NAME/$WORKDIR

  if [ -d $WORKDIR_FULL ]; then
      setup_log "🗑️ Deleting WORKDIR ${WORKDIR} from an unsuccessful previous attempt"
      rm -rf $WORKDIR_FULL
  fi

	setup_log "📂 Creating working directory ${WORKDIR_FULL}"
	mkdir -p $WORKDIR_FULL

	setup_log "🔗 Creating symbolic link for ${WORKDIR_FULL}"
	ln -s $WORKDIR_FULL /home/$DEPLOYER_USERNAME/$WORKDIR

done

wordwrap

if $INSTALL_PROXY ; then
    setup_proxy $BOILERPLATE
fi

wordwrap

setup_log "🔁 Changing owner of the root working directory to $DEPLOYER_USERNAME"
chown -R $DEPLOYER_USERNAME.$DEPLOYER_USERNAME ${ROOT_WORKDIR}/$VENDOR_NAME

wordwrap

setup_log "🧹 Cleaning up"
apt-get autoremove -y
apt-get clean -y

install_report "--------------------------------------------------------------------------------"
install_report "Finished on: $(TZ=$TIMEZONE date)"
install_report "--------------------------------------------------------------------------------"

# Finish
setup_log "✅ Concluded! Please restart the server to apply some changes."
wordwrap
cat install-report.txt
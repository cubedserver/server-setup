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

if [[ -z $DOCKER_COMPOSE_VERSION ]]; then
  DOCKER_COMPOSE_VERSION="1.27.4"
fi

if [[ -z $WORKDIRS ]]; then
    WORKDIRS="apps backups"
fi

if [[ -z $ROOT_WORKDIR ]]; then
    ROOT_WORKDIR="/var"
fi

if [[ -z $BOILERPLATE ]]; then
    BOILERPLATE=nginx
fi

if [[ -z $TIMEZONE ]]; then
    TIMEZONE=America/Sao_Paulo
fi

# greet
function greet() {
    # Welcome users
    echo -e "\n\e[32m******************************************\e[39m"
    echo -e "\e[32m**           Basic Host Setup           **\e[39m"
    echo -e "\e[32m******************************************\e[39m\n\n"
}

# Outputs install log line
function setup_log() {
    echo -e "\033[1;32m$*\033[m"
}

function install_report() {
    echo $* >> install-report.txt
}

function setup_proxy {

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
    
    setup_log "📂 Creating working directory ${WORKDIR} for the $BOILERPLATE Proxy"
    mkdir -p $WORKDIR

    PROXY_FULL_PATH=${WORKDIR}/${DIR_NAME}
    
    setup_log "📥 Downloading boilerplate ${BOILERPLATE}"
    wget $BOILERPLATE_URL -O $FILE_ZIPED

    setup_log "🗃️ Extracting files from ${FILE_ZIPED}"
    unzip -q $FILE_ZIPED && rm $FILE_ZIPED && mv ${ORIGINAL_NAME}-master $PROXY_FULL_PATH

    if [[ ! -z $YOUR_EMAIL ]]; then
        setup_log "📧 Overriding test email from configuration files"
        find $PROXY_FULL_PATH -type f -exec sed -i "s/$EXAMPLE_EMAIL/$YOUR_EMAIL/g" {} \;
    fi

    if [[ ! -z $YOUR_DOMAIN ]]; then
        setup_log "🌐 Overriding test domain for configuration files"
        find $PROXY_FULL_PATH -type f -exec sed -i "s/$EXAMPLE_DOMAIN/$YOUR_DOMAIN/g" {} \;
    fi

    setup_log "⚡ Starting reverse proxy containers"
    docker-compose -f ${PROXY_FULL_PATH}/docker-compose.yml up -d
    install_report "\n\nServices started\n"
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

install_report "Started in: $(TZ=$TIMEZONE date)"

greet

setup_log "🎲 Do you want to use a file of environment variables to go faster?"
read -r -p "Type 'Y' to download and edit the file or 'n' to skip: " USE_ENV_TEMPLATE
if [ $USE_ENV_TEMPLATE == "Y" ]; then
  setup_log "📥 Downloading template"
  curl -fsSL $ENV_TEMPLATE -o .env
  nano .env
fi

echo -e "\n"

# If there is a env file, source it
if [ -f "./.env" ]; then
   source ./.env
fi

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

# define timezone
setup_log "🕒 Updating packages and setting the timezone"
apt-get update -y
timedatectl set-timezone $TIMEZONE

echo -e "\n"

# define senha root
setup_log "🔑 Setting the root password"

if [[ -z $ROOT_PASSWORD ]]; then
  passwd
else
  echo $ROOT_PASSWORD | passwd > /dev/null 2>&1
fi

# cria chave SSH do root caso não exista
if [ ! -e /root/.ssh/id_rsa ]; then
   setup_log "🔑 Creating SSH Keys"
   ssh-keygen -t rsa
fi

# criar arquivo known_hosts caso não exista
if [ ! -e /root/.ssh/known_hosts ]; then
   setup_log "📄 Creating file known_hosts"
   touch /root/.ssh/known_hosts
fi

# criar arquivo authorized_keys caso não exista
if [ ! -e /root/.ssh/authorized_keys ]; then
  setup_log "📄 Creating file authorized_keys"
  touch /root/.ssh/authorized_keys
fi

echo -e "\n"

# adiciona bitbucket.org, gitlab.com, github.com
setup_log "⚪ Adding bitbucket.org to trusted hosts"
ssh-keyscan bitbucket.org >> /root/.ssh/known_hosts

echo -e "\n"

setup_log "⚪ Adding gitlab.com to trusted hosts"
ssh-keyscan gitlab.com >> /root/.ssh/known_hosts

echo -e "\n"

setup_log "⚪ Adding github.com to trusted hosts"
ssh-keyscan github.com >> /root/.ssh/known_hosts

echo -e "\n"

# pedir nome de usuário do novo usuário padrão
if [[ -z $DEPLOYER_USERNAME ]]; then
  read -r -p "👤 Enter a username for the user who will deploy applications (e.g. deployer):" DEPLOYER_USERNAME
  if [ -z $DEPLOYER_USERNAME ]; then
      echo "❌ No user name entered, aborting." 1>&2
      exit 1
  fi
fi

if [[ -z $VENDOR_NAME ]]; then
  read -r -p "🏢 Enter a default folder name where the apps, storage and backups will be (e.g. yourcompany): " VENDOR_NAME
  if [[ -z $VENDOR_NAME ]]; then
      echo "❌ No default folder name entered, aborting." 1>&2
      exit 1
  fi
fi

echo -e "\n"

# adiciona usuário padrão
setup_log "👤 Creating standard user"
useradd -s /bin/bash -d /home/$DEPLOYER_USERNAME -m -U $DEPLOYER_USERNAME

if [[ -z $DEPLOYER_PASSWORD ]]; then
  passwd $DEPLOYER_USERNAME
else
  echo $DEPLOYER_PASSWORD | passwd $DEPLOYER_USERNAME > /dev/null 2>&1
fi

echo -e "\n"

# copia SSH authorized_keys
setup_log "🗂️ Copying the SSH public key to the home directory of the new default user"
if [ ! -d /home/$DEPLOYER_USERNAME/.ssh ]; then
  mkdir /home/$DEPLOYER_USERNAME/.ssh
fi
cp -r /root/.ssh/* /home/$DEPLOYER_USERNAME/.ssh/
chown -R $DEPLOYER_USERNAME.$DEPLOYER_USERNAME /home/$DEPLOYER_USERNAME/.ssh

echo -e "\n"

# add standard user to sudoers
setup_log "💪 Adding $DEPLOYER_USERNAME to sudoers with full privileges"
echo "$DEPLOYER_USERNAME ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/$DEPLOYER_USERNAME
chmod 0440 /etc/sudoers.d/$DEPLOYER_USERNAME

echo -e "\n"

setup_log "🟢 Installing essential programs (git zip unzip curl wget acl)"
apt-get install -y git zip unzip curl wget acl

echo -e "\n"

setup_log "🐳 Installing docker"
curl -fsSL get.docker.com -o get-docker.sh && sh get-docker.sh

echo -e "\n"

setup_log "📦 Installing docker-compose"
curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-Linux-x86_64" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

echo -e "\n"

setup_log "🟢 Adding user $DEPLOYER_USERNAME to group www-data"
usermod -aG www-data $DEPLOYER_USERNAME

setup_log "🟢 Adding user $DEPLOYER_USERNAME to the docker group"
usermod -aG docker $DEPLOYER_USERNAME

echo -e "\n"

for WORKDIR in $WORKDIRS; do

  WORKDIR_FULL=${ROOT_WORKDIR}/$VENDOR_NAME/$WORKDIR

	setup_log "📂 Creating working directory ${WORKDIR_FULL}"
	mkdir -p $WORKDIR_FULL

	setup_log "🔗 Creating symbolic link for ${WORKDIR_FULL}"
	ln -s $WORKDIR_FULL /home/$DEPLOYER_USERNAME/$WORKDIR

done

echo -e "\n"

if [[ ! -z $INSTALL_PROXY ]]; then

  setup_log "Do you want to install the Reverse Proxy for docker containers?"
  read -r -p "Type 'Y' to prepare the services or 'n' to skip:" INSTALL_PROXY
  if [ $INSTALL_PROXY == "Y" ]; then
      setup_proxy
  fi
fi

echo -e "\n"

setup_log "🔁 Changing owner of the root working directory to $DEPLOYER_USERNAME"
chown -R $DEPLOYER_USERNAME.$DEPLOYER_USERNAME ${ROOT_WORKDIR}/$VENDOR_NAME

echo -e "\n"

setup_log "🧹 Cleaning up"
apt-get autoremove -y
apt-get clean -y

install_report "Finished on: $(TZ=$TIMEZONE date)"

# Finish
setup_log "✅ Concluded! Please restart the server to apply some changes."
echo -e "\n"
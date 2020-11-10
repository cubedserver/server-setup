#!/bin/bash

if [ -f "./.env" ]; then
   source ./.env
fi


if [[ -z $DOCKER_COMPOSE_VERSION ]]; then
  DOCKER_COMPOSE_VERSION="1.27.4"
fi

# Outputs install log line
function setup_log() {
    echo -e "\033[1;32m$*\033[m"
}

if [ "$(id -u)" != "0" ]; then
   setup_log "Sorry! This script must be run as root." 1>&2
   exit 1
fi

# prompt
setup_log "This script will run the initial settings on this server."
read -r -p "Type 'S' to continue or any key to cancel: " GO
if [ "$GO" != "S" ]; then
    setup_log "Aborting." 1>&2
    exit 1
fi

# define timezone
setup_log "Updating packages and setting the time zone..."
apt-get update
apt-get dist-upgrade
apt-get autoremove
dpkg-reconfigure tzdata

echo -e "\n"

# define senha root
setup_log "Setting the root password..."

if [[ -z $ROOT_PASSWORD ]]; then
  passwd
else
  echo $ROOT_PASSWORD | passwd > /dev/null 2>&1
fi

# cria chave SSH do root caso não exista
if [ ! -e /root/.ssh/id_rsa ]; then
   setup_log "Creating SSH Keys..."
   ssh-keygen -t rsa
fi

# criar arquivo known_hosts caso não exista
if [ ! -e /root/.ssh/known_hosts ]; then
   setup_log "Creating file known_hosts..."
   touch /root/.ssh/known_hosts
fi

# criar arquivo authorized_keys caso não exista
if [ ! -e /root/.ssh/authorized_keys ]; then
  setup_log "Creating file authorized_keys..."
  touch /root/.ssh/authorized_keys
fi

echo -e "\n"

# adiciona bitbucket.org, gitlab.com, github.com
setup_log "Adding bitbucket.org to trusted hosts..."
ssh-keyscan bitbucket.org >> /root/.ssh/known_hosts

setup_log "Adding gitlab.com to trusted hosts..."
ssh-keyscan gitlab.com >> /root/.ssh/known_hosts

setup_log "Adding github.com to trusted hosts..."
ssh-keyscan github.com >> /root/.ssh/known_hosts

echo -e "\n"

# pedir nome de usuário do novo usuário padrão
if [[ -z $DEPLOYER_USERNAME ]]; then
  read -r -p "Enter a username for the user who will deploy applications (e.g. deployer):" DEPLOYER_USERNAME
  if [ -z $DEPLOYER_USERNAME ]; then
      echo "No user name entered, aborting." 1>&2
      exit 1
  fi
fi

echo -e "\n"

# pedir nome de "vendor" que será utilizado como prefixo nas pastas de apps, storage e backups. Ex.: nome de um organização como google ou codions
if [[ -z $VENDOR_NAME ]]; then
  read -r -p "Enter a default folder name where the apps, storage and backups will be (e.g. yourcompany): " VENDOR_NAME
  if [[ -z $VENDOR_NAME ]]; then
      echo "No default folder name entered, aborting." 1>&2
      exit 1
  fi
fi

echo -e "\n"

# adiciona usuário padrão
setup_log "Creating standard user..."
useradd -s /bin/bash -d /home/$DEPLOYER_USERNAME -m -U $DEPLOYER_USERNAME

if [[ -z $DEPLOYER_PASSWORD ]]; then
  passwd $DEPLOYER_USERNAME
else
  echo $DEPLOYER_PASSWORD | passwd $DEPLOYER_USERNAME > /dev/null 2>&1
fi

echo -e "\n"

# copia SSH authorized_keys
setup_log "Copying the SSH public key to the home directory of the new default user..."
if [ ! -d /home/$DEPLOYER_USERNAME/.ssh ]; then
  mkdir /home/$DEPLOYER_USERNAME/.ssh
fi
cp -r /root/.ssh/* /home/$DEPLOYER_USERNAME/.ssh/
chown -R $DEPLOYER_USERNAME.$DEPLOYER_USERNAME /home/$DEPLOYER_USERNAME/.ssh

echo -e "\n"

# adiciona usuário padrão aos sudoers
setup_log "Adding $DEPLOYER_USERNAME to sudoers with full privileges..."
echo "$DEPLOYER_USERNAME ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/$DEPLOYER_USERNAME
chmod 0440 /etc/sudoers.d/$DEPLOYER_USERNAME

echo -e "\n"

# instala git, zip, unzip
setup_log "Installing essential programs (git zip unzip curl wget acl)"
apt-get install -yq git zip unzip curl wget acl

echo -e "\n"

setup_log "Installing docker..."
curl -fsSL get.docker.com -o get-docker.sh && sh get-docker.sh

echo -e "\n"

setup_log "Installing docker-compose..."
curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-Linux-x86_64" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

echo -e "\n"

setup_log "Adding user $DEPLOYER_USERNAME to group www-data..."
usermod -aG www-data $DEPLOYER_USERNAME

setup_log "Adding user $DEPLOYER_USERNAME to the docker group..."
usermod -aG docker $DEPLOYER_USERNAME

setup_log "Creating working directory for containers (applications)..."
mkdir -p /var/$VENDOR_NAME/apps

setup_log "Creating working directory for container volumes (storage)..."
mkdir -p /var/$VENDOR_NAME/storage

setup_log "Creating working directory for backups..."
mkdir -p /var/$VENDOR_NAME/backups

setup_log "Changing owner of the root working directory to $DEPLOYER_USERNAME..."
chown -R $DEPLOYER_USERNAME.$DEPLOYER_USERNAME /var/$VENDOR_NAME

echo -e "\n"

setup_log "Creating symbolic link to the application folder..."
ln -s /var/$VENDOR_NAME/apps /home/$DEPLOYER_USERNAME/apps

setup_log "Creating symbolic link to the storage folder..."
ln -s /var/$VENDOR_NAME/storage /home/$DEPLOYER_USERNAME/storage

setup_log "Creating symbolic link to the backups folder..."
ln -s /var/$VENDOR_NAME/backups /home/$DEPLOYER_USERNAME/storage

setup_log "Cleaning up..."
apt-get autoremove
apt-get clean

# Finish
setup_log "Concluded! Please restart the server to apply some changes."
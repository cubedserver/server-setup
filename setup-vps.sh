#!/bin/bash

# nginx proxy files
BOILERPLATE_NGINX_URL="https://github.com/cubedserver/docker-boilerplate-nginx-proxy/archive/master.zip"
ORIGINAL_NAME_NGINX=docker-boilerplate-nginx-proxy
DIR_NAME_NGINX=nginx-proxy

# traefik proxy files
BOILERPLATE_TRAEFIK_URL="https://github.com/cubedserver/docker-boilerplate-traefik-proxy/archive/master.zip"
ORIGINAL_NAME_TRAEFIK=docker-boilerplate-traefik-proxy
DIR_NAME_TRAEFIK=traefik-proxy

# Example values that will be replaced
EXAMPLE_DOMAIN=domain.test
EXAMPLE_EMAIL=email@domain.test

# Defaults
INSTALL_PROXY=true
SHOW_LOGS=true
SSH_PASSPHRASE=
TIMEZONE=America/Sao_Paulo
DOCKER_COMPOSE_VERSION=1.29.2
ROOT_PASSWORD=YourSecurePassword
DEFAULT_USER=cubed
DEFAULT_PASSWORD=YourSecurePassword
ROOT_WORKDIR=/home/$DEFAULT_USER
WORKDIRS=apps,backups
DOCKER_NETWORKS=nginx-proxy,internal
BOILERPLATE=nginx
ADDITIONAL_APPS=mysql,postgres,redis,whoami,adminer,phpmyadmin,portainer
YOUR_DOMAIN=yourdomain.com
YOUR_EMAIL=email@yourdomain.com
SSH_KEYSCAN='bitbucket.org,gitlab.com,github.com'

MYSQL_PASSWORD=
POSTGRES_PASSWORD=
REDIS_PASSWORD=
TRAEFIK_PASSWORD=


WEBHOOK_URL=

usage() {
    set +x
    cat 1>&2 <<HERE
Script for initial configurations of Docker, Docker Compose and Reverse Proxy.
USAGE:
    wget -qO- https://raw.githubusercontent.com/cubedserver/server-setup/master/setup-vps.sh | bash -s -- [OPTIONS]
OPTIONS:

-t|--timezone               Standard system timezone
--docker-compose-version    Version of the docker compose to be installed
--root-password             New root user password. The script forces the password update
--default-user              Alternative user (with super powers) that will be used for deploys and remote access later
--default-password
--workdir                   Folder where all files of this setup will be stored
--spaces                    Subfolders where applications will be allocated
-n|--docker-networks        Docker networks to be created
-b|--boilerplate            Proxy templates to be installed. Currently traefik and nginx are available
-a|--additional-apps        Additional applications that will be installed along with the proxy
-d|--domain                 If you have configured your DNS and pointed A records to this host, this will be the domain used to access the services
                            After everything is set up, you can access the services as follows: service.yourdomain.com
-e|--email                  Email that Let's Encrypt will use to generate SSL certificates
--ssh-passphrase            Provides a passphrase for the ssh key

OPTIONS (Service Credentials):
--mysql-password            MySQL root password
--postgres-password         PostgreSQL password
--redis-password            Redis password
--traefik-password          Traefik admin password  

OPTIONS (Webhook):
--webhook-url               Ping URL With Provisioning Updates
HERE
}

check_apache2() {
  if dpkg -l | grep -q apache2-bin; then
    error "You must uninstall the Apache2 server first";
  fi
}

POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -h|--help)
        usage
        exit 0
        ;;
    --ssh-passphrase)
        SSH_PASSPHRASE="$2"
        shift # past argument
        shift # past value
        ;;

    -t|--timezone)
        TIMEZONE="$2"
        shift
        shift
        ;;

    --docker-compose-version)
        DOCKER_COMPOSE_VERSION="$2"
        shift
        shift
        ;;

    --root-password)
        ROOT_PASSWORD="$2"
        shift
        shift
        ;;

    --default-user)
        DEFAULT_USER="$2"
        shift
        shift
        ;;
    --default-password)
        DEFAULT_PASSWORD="$2"
        shift
        shift
        ;;

    --workdir)
        ROOT_WORKDIR="$2"
        shift
        shift
        ;;

    --spaces)
        WORKDIRS="$2"
        shift
        shift
        ;;

    -n|--docker-networks)
        DOCKER_NETWORKS="$2"
        shift
        shift
        ;;

    -b|--boilerplate)
        BOILERPLATE="$2"
        shift
        shift
        ;;

    -a|--additional-apps)
        ADDITIONAL_APPS="$2"
        shift
        shift
        ;;

    -d|--domain)
        YOUR_DOMAIN="$2"
        shift
        shift
        ;;

    -e|--email)
        YOUR_EMAIL="$2"
        shift
        shift
        ;;

    --mysql-password)
        MYSQL_PASSWORD="$2"
        shift
        shift
        ;;

    --postgres-password)
        POSTGRES_PASSWORD="$2"
        shift
        shift
        ;;

    --redis-password)
        REDIS_PASSWORD="$2"
        shift
        shift
        ;;

    --traefik-password)
        TRAEFIK_PASSWORD=$(htpasswd -nb admin $2)

        shift
        shift
        ;;

    --webhook-url)
        WEBHOOK_URL="$2"
        shift
        shift
        ;;

    *)    # unknown option
        POSITIONAL+=("$1") # save it in an array for later
        echo "Parameter not known: $1"
        exit 1
        ;;
esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters


# Ping URL With Provisioning Updates
function provision_ping {
    if [[ ! -z $WEBHOOK_URL ]]; then

curl --max-time 15 --connect-timeout 60 --silent $WEBHOOK_URL \
-H "Accept: application/json" \
-H "Content-Type:application/json" \
--data @<(cat <<EOF
    {
      "log": "$1"
    }
EOF
) > /dev/null 2>&1


    fi
}

# Outputs install log line
function setup_log() {
  if $SHOW_LOGS ; then
      provision_ping "$1"
      echo -e "\033[1;32m${1}\033[m"
  fi
}

function error() {
    provision_ping "$1"
    echo "\033[0;31m${1}\033[m" >&2
    exit 1
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
    WORKDIR=${ROOT_WORKDIR}/apps/core

    if [ -d $WORKDIR ]; then
        setup_log "🗑️  Deleting previous files from an unsuccessful previous attempt"
        rm -rf $WORKDIR
    fi

    setup_log "📂 Creating working directory ${WORKDIR} for the $BOILERPLATE Proxy"
    mkdir -p $WORKDIR

    PROXY_FULL_PATH=${WORKDIR}/${DIR_NAME}
    
    setup_log "📥 Downloading boilerplate ${BOILERPLATE}"
    wget -q $BOILERPLATE_URL -O $FILE_ZIPED

    if [ ! -f $FILE_ZIPED ]; then
        setup_log "❌ Failed to download proxy files. Skipping..."
    else
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

        # Update service credentials
        setup_log "🔑 Updating Service Credentials"

        if [[ ! -z $MYSQL_PASSWORD ]]; then
            find $PROXY_FULL_PATH/examples/mysql -type f -exec sed -i "s/your_secure_password/$MYSQL_PASSWORD/g" {} \;
        fi

        if [[ ! -z $POSTGRES_PASSWORD ]]; then
            find $PROXY_FULL_PATH/examples/postgres -type f -exec sed -i "s/your_secure_password/$POSTGRES_PASSWORD/g" {} \;
        fi

        if [[ ! -z $REDIS_PASSWORD ]]; then
            find $PROXY_FULL_PATH/examples/redis -type f -exec sed -i "s/your_secure_password/$REDIS_PASSWORD/g" {} \;
        fi

        if [[ ! -z $TRAEFIK_PASSWORD ]]; then
            OLD_TRAEFIK_PASSWORD="admin:\$apr1\$hR1niB3v\$rrLbUoAuySzeBye3cRHYB.";

            sed -i "s/$OLD_TRAEFIK_PASSWORD/$TRAEFIK_PASSWORD/g" ${PROXY_FULL_PATH}/traefik_dynamic.toml
        fi

        for NETWORK_NAME in $(echo $DOCKER_NETWORKS | sed "s/,/ /g"); do
            create_docker_network $NETWORK_NAME
        done 

        setup_log "⚡ Starting reverse proxy containers"
        docker-compose -f ${PROXY_FULL_PATH}/docker-compose.yml up -d

        install_report "Services started"
        install_report "${PROXY_FULL_PATH}/docker-compose.yml"

        # Moves the app folder to the working directory root
        if [[ ! -z $ADDITIONAL_APPS ]]; then
            for APP in $(echo $ADDITIONAL_APPS | sed "s/,/ /g"); do
                if [ -d ${PROXY_FULL_PATH}/examples/${APP} ]; then
                    mv ${PROXY_FULL_PATH}/examples/${APP} ${WORKDIR}/${APP}

                    setup_log "⚡ Starting ${APP} container"
                    docker-compose -f ${WORKDIR}/${APP}/docker-compose.yml up -d
                    install_report "${WORKDIR}/${APP}/docker-compose.yml"
                else
                    setup_log "❌ App ${APP} files not found. Skipping..."
                fi
            done    
        fi
    fi

}

install_report "Started in: $(TZ=$TIMEZONE date)"

if [ "$(id -u)" != "0" ]; then
   error "❌ Sorry! This script must be run as root."
fi

check_apache2

# Update timezone
setup_log "🕒 Updating packages and setting the timezone"
apt-get update -qq >/dev/null
timedatectl set-timezone $TIMEZONE

setup_log "🟢 Installing essential programs (git zip unzip curl wget acl)"
apt-get install -y -qq --no-install-recommends git zip unzip curl wget acl apache2-utils

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
else
    setup_log "📦 Docker-compose previously installed! Skipping..."
fi

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

  if [[ -z $SSH_PASSPHRASE ]]; then
    ssh-keygen -q -t rsa -b 4096 -f id_rsa -C "$YOUR_EMAIL" -N ''
  else
    ssh-keygen -q -t rsa -b 4096 -f id_rsa -C "$YOUR_EMAIL" -N "$SSH_PASSPHRASE"
  fi
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
for S_KEYSCAN in $(echo $SSH_KEYSCAN | sed "s/,/ /g"); do
  setup_log "⚪ Adding $S_KEYSCAN to trusted hosts"
  ssh-keyscan $S_KEYSCAN >> /root/.ssh/known_hosts
done

wordwrap

# Adds standard user, if one does not exist.
if [ `sed -n "/^$DEFAULT_USER/p" /etc/passwd` ]; then

    setup_log "👤 User $DEFAULT_USER already exists. Skipping..."

else
    setup_log "👤 Creating standard user"
    useradd -s /bin/bash -d /home/$DEFAULT_USER -m -U $DEFAULT_USER

    if [[ -z $DEFAULT_PASSWORD ]]; then
      passwd $DEFAULT_USER
    else
      echo $DEFAULT_PASSWORD | passwd $DEFAULT_USER > /dev/null 2>&1
    fi

    wordwrap

    # Copy SSH authorized_keys
    setup_log "🗂️ Copying the SSH public key to the home directory of the new default user"
    if [ ! -d /home/$DEFAULT_USER/.ssh ]; then
      mkdir /home/$DEFAULT_USER/.ssh
    fi
    cp -r /root/.ssh/* /home/$DEFAULT_USER/.ssh/
    chown -R $DEFAULT_USER.$DEFAULT_USER /home/$DEFAULT_USER/.ssh

    wordwrap

    # add standard user to sudoers
    setup_log "💪 Adding $DEFAULT_USER to sudoers with full privileges"
    echo "$DEFAULT_USER ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/$DEFAULT_USER
    chmod 0440 /etc/sudoers.d/$DEFAULT_USER

    wordwrap

    setup_log "🟢 Adding user $DEFAULT_USER to group www-data"
    usermod -aG www-data $DEFAULT_USER

    setup_log "🟢 Adding user $DEFAULT_USER to the docker group"
    usermod -aG docker $DEFAULT_USER
fi

wordwrap

for WORKDIR in $(echo $WORKDIRS | sed "s/,/ /g"); do

  WORKDIR_FULL=${ROOT_WORKDIR}/$WORKDIR

  if [ -d $WORKDIR_FULL ]; then
      setup_log "🗑️  Deleting WORKDIR ${WORKDIR} from an unsuccessful previous attempt"
      rm -rf $WORKDIR_FULL
  fi

	setup_log "📂 Creating working directory ${WORKDIR_FULL}"
	mkdir -p $WORKDIR_FULL

  wordwrap

done

if $INSTALL_PROXY ; then
    setup_proxy $BOILERPLATE
fi

wordwrap

setup_log "🔁 Changing owner of the root working directory to $DEFAULT_USER"
chown -R $DEFAULT_USER.$DEFAULT_USER ${ROOT_WORKDIR}

wordwrap

setup_log "🧹 Cleaning up"
apt-get autoremove -y
apt-get clean -y

install_report "Finished on: $(TZ=$TIMEZONE date)"

# Finish
setup_log "✅ Concluded!"
wordwrap
cat install-report.txt
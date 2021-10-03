#!/bin/bash

# Example values that will be replaced
EXAMPLE_DOMAIN=yourdomain.local
EXAMPLE_EMAIL=email@yourdomain.local

INSTALL_PROXY=true
SSH_PASSPHRASE=

# Defaults
: ${TEMPLATE_NGINX_URL:='https://github.com/cubedserver/docker-nginx-proxy/archive/master.zip'}
: ${TEMPLATE_TRAEFIK_URL:='https://github.com/cubedserver/docker-traefik-proxy/archive/master.zip'}

: ${YOUR_DOMAIN:='yourdomain.local'}
: ${YOUR_EMAIL:='email@yourdomain.local'}

: ${DOCKER_COMPOSE_VERSION:='1.29.2'}

: ${SSH_KEYSCAN:='bitbucket.org,gitlab.com,github.com'}
: ${WORKDIRS:='apps,backups'}
: ${TEMPLATE:='nginx'}
: ${APP_TEMPLATES:='portainer,mysql,postgres,redis,adminer,phpmyadmin,whoami'}

: ${DEFAULT_TIMEZONE:='America/Sao_Paulo'}
: ${ROOT_PASSWORD:=`openssl rand -base64 8`}

: ${DEFAULT_USER:='cubed'}
: ${DEFAULT_USER_PASSWORD:=`openssl rand -base64 8`}
: ${DEFAULT_WORKDIR:='/home/cubed'}

: ${MYSQL_PASSWORD:=`openssl rand -base64 8`}
: ${POSTGRES_PASSWORD:=`openssl rand -base64 8`}
: ${REDIS_PASSWORD:=`openssl rand -base64 8`}
: ${TRAEFIK_PASSWORD:=`openssl rand -base64 8`}

WEBHOOK_URL=

usage() {
    set +x
    cat 1>&2 <<HERE
Script for initial configurations of Docker, Docker Compose and Reverse Proxy.
USAGE:
    wget -qO- https://raw.githubusercontent.com/cubedserver/server-setup/master/server-setup.sh | bash -s -- [OPTIONS]
OPTIONS:

-h|--help                   Print help
-t|--timezone               Standard system timezone
--docker-compose-version    Version of the docker compose to be installed
--root-password             New root user password. The script forces the password update
--default-user              Alternative user (with super powers) that will be used for deploys and remote access later
--default-user-password
--workdir                   Folder where all files of this setup will be stored
--spaces                    Subfolders where applications will be allocated (eg. apps, backups)
-n|--docker-networks        Docker networks to be created
-b|--proxy-template         Proxy templates to be installed. Currently traefik and nginx are available
-a|--app-templates          Additional applications that will be installed along with the proxy
-d|--domain                 If you have configured your DNS and pointed A records to this host, this will be the domain used to access the services
                            After everything is set up, you can access the services as follows: service.yourdomain.local
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
    error "You must uninstall the Apache2 server first.";
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
        shift 2
        ;;

    -t|--timezone)
        DEFAULT_TIMEZONE="$2"
        shift 2
        ;;

    --docker-compose-version)
        DOCKER_COMPOSE_VERSION="$2"
        shift 2
        ;;

    --root-password)
        ROOT_PASSWORD="$2"
        shift 2
        ;;

    --default-user)
        DEFAULT_USER="$2"
        shift 2
        ;;
    --default-user-password)
        DEFAULT_USER_PASSWORD="$2"
        shift 2
        ;;

    --workdir)
        DEFAULT_WORKDIR="$2"
        shift 2
        ;;

    --spaces)
        WORKDIRS="$2"
        shift 2
        ;;

    -n|--docker-networks)
        DOCKER_NETWORKS="$2"
        shift 2
        ;;

    -b|--proxy-template)
        TEMPLATE="$2"
        shift 2
        ;;

    -a|--app-templates)
        APP_TEMPLATES="$2"
        shift 2
        ;;

    -d|--domain)
        YOUR_DOMAIN="$2"
        shift 2
        ;;

    -e|--email)
        YOUR_EMAIL="$2"
        shift 2
        ;;

    --mysql-password)
        MYSQL_PASSWORD="$2"
        shift 2
        ;;

    --postgres-password)
        POSTGRES_PASSWORD="$2"
        shift 2
        ;;

    --redis-password)
        REDIS_PASSWORD="$2"
        shift 2
        ;;

    --traefik-password)
        TRAEFIK_PASSWORD="$2"
        shift 2
        ;;

    --webhook-url)
        WEBHOOK_URL="$2"
        shift 2
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
-H "Content-Type: application/json" \
--data @<(cat <<EOF
    {
      "message": "$1",
      "status": "IN_PROGRESS"
    }
EOF
) > /dev/null 2>&1

    fi
}

# Outputs install log line
function setup_log() {
    provision_ping "$1"
    echo -e $1
}

function error() {
    provision_ping "$1"
    echo "$1" >&2
    exit 1
}

function install_report() {
    echo $* >> install-report.txt
}

function create_docker_network() {
    NETWORK_NAME=$1
    setup_log "---> ⚡ Creating Docker network ${NETWORK_NAME}"
    docker network ls|grep $NETWORK_NAME > /dev/null || docker network create $NETWORK_NAME
}

# Remove images, volumes and containers from a previous unsuccessful attempt
function docker_reset() {
  CONTAINERS=$(docker ps -a -q)
  if [[ ! -z $CONTAINERS ]]; then
      docker stop $CONTAINERS
      docker rm $CONTAINERS
      docker system prune -a --force
  fi

  VOLUMES=$(docker volume ls -q)
  if [[ ! -z $VOLUMES ]]; then
      docker volume rm $VOLUMES
  fi
}

function setup_proxy() {

  TEMPLATE=$1

  if [ $TEMPLATE == "nginx" ]; then
      TEMPLATE_URL=$TEMPLATE_NGINX_URL
      ORIGINAL_NAME=docker-nginx-proxy
      DIR_NAME=nginx-proxy
      ${DOCKER_NETWORKS:='nginx-proxy,internal'}
  else
      TEMPLATE_URL=$TEMPLATE_TRAEFIK_URL
      ORIGINAL_NAME=docker-traefik-proxy
      DIR_NAME=traefik-proxy
      ${DOCKER_NETWORKS:='web,internal'}

      TRAEFIK_CREDENTIALS=$(htpasswd -nb admin $TRAEFIK_PASSWORD)
  fi

    FILE_ZIPED=${ORIGINAL_NAME}.zip
    WORKDIR=${DEFAULT_WORKDIR}/apps

    if [ -d $WORKDIR ]; then
        setup_log "---> 🗑️  Deleting previous files from an unsuccessful previous attempt"
        rm -rf $WORKDIR
    fi

    setup_log "---> 📂 Creating working directory ${WORKDIR} for the $TEMPLATE Proxy"
    mkdir -p $WORKDIR

    PROXY_FULL_PATH=${WORKDIR}/${DIR_NAME}
    
    setup_log "---> 📥 Downloading template ${TEMPLATE}"
    wget -q $TEMPLATE_URL -O $FILE_ZIPED

    if [ ! -f $FILE_ZIPED ]; then
        setup_log "---> ❌ Failed to download proxy files. Skipping..."
    else
        setup_log "---> 🗃️ Extracting files from ${FILE_ZIPED}"
        unzip -q $FILE_ZIPED && rm $FILE_ZIPED && mv ${ORIGINAL_NAME}-master $PROXY_FULL_PATH

        if [[ ! -z $YOUR_EMAIL ]]; then
            setup_log "---> 📧 Overriding ${EXAMPLE_EMAIL} to ${YOUR_EMAIL} email from configuration files"
            find $PROXY_FULL_PATH -type f -exec sed -i "s/$EXAMPLE_EMAIL/$YOUR_EMAIL/g" {} \;
            install_report "---> EXAMPLE_EMAIL: $EXAMPLE_EMAIL"
        fi

        if [[ ! -z $YOUR_DOMAIN ]]; then
            setup_log "---> 🌐 Overriding ${EXAMPLE_DOMAIN} to ${YOUR_DOMAIN} domain for configuration files"
            find $PROXY_FULL_PATH -type f -exec sed -i "s/$EXAMPLE_DOMAIN/$YOUR_DOMAIN/g" {} \;
            install_report "---> YOUR_DOMAIN: $YOUR_DOMAIN"
        fi

        # Update service credentials
        setup_log "---> 🔑 Updating Service Credentials"

        if [[ ! -z $MYSQL_PASSWORD ]]; then
            sed -i "s/your_secure_password/$MYSQL_PASSWORD/g" $PROXY_FULL_PATH/templates/mysql/docker-compose.yml
            install_report "---> MYSQL_PASSWORD: $MYSQL_PASSWORD"
        fi

        if [[ ! -z $POSTGRES_PASSWORD ]]; then
            sed -i "s/your_secure_password/$POSTGRES_PASSWORD/g" $PROXY_FULL_PATH/templates/postgres/docker-compose.yml
            install_report "---> POSTGRES_PASSWORD: $POSTGRES_PASSWORD"
        fi

        if [[ ! -z $REDIS_PASSWORD ]]; then
            sed -i "s/your_secure_password/$REDIS_PASSWORD/g" $PROXY_FULL_PATH/templates/redis/docker-compose.yml
            install_report "---> REDIS_PASSWORD: $REDIS_PASSWORD"
        fi

        if [[ ! -z $TRAEFIK_CREDENTIALS ]]; then
            OLD_TRAEFIK_CREDENTIALS="admin:\$apr1\$hR1niB3v\$rrLbUoAuySzeBye3cRHYB.";
            sed -i "s/$OLD_TRAEFIK_CREDENTIALS/$TRAEFIK_CREDENTIALS/g" ${PROXY_FULL_PATH}/docker-compose.yml
            install_report "---> TRAEFIK_PASSWORD: $TRAEFIK_PASSWORD"

            if [[ ! -e ${PROXY_FULL_PATH}/acme.json ]]; then
                touch ${PROXY_FULL_PATH}/acme.json
            fi

            chmod 600 ${PROXY_FULL_PATH}/acme.json
        fi

        for NETWORK_NAME in $(echo $DOCKER_NETWORKS | sed "s/,/ /g"); do
            create_docker_network $NETWORK_NAME
        done 

        setup_log "---> ⚡ Starting reverse proxy containers"
        docker-compose -f ${PROXY_FULL_PATH}/docker-compose.yml up -d

        install_report "Services started"
        install_report "${PROXY_FULL_PATH}/docker-compose.yml"

        # Moves the app folder to the working directory root
        if [[ ! -z $APP_TEMPLATES ]]; then
            for APP in $(echo $APP_TEMPLATES | sed "s/,/ /g"); do
                if [ -d ${PROXY_FULL_PATH}/templates/${APP} ]; then
                    mv ${PROXY_FULL_PATH}/templates/${APP} ${WORKDIR}/${APP}

                    setup_log "---> ⚡ Starting ${APP} container"
                    docker-compose -f ${WORKDIR}/${APP}/docker-compose.yml up -d
                    install_report "${WORKDIR}/${APP}/docker-compose.yml"
                else
                    setup_log "---> ❌ App ${APP} files not found. Skipping..."
                fi
            done    
        fi
    fi

}

install_report "Started in: $(TZ=$DEFAULT_TIMEZONE date)"

if [ "$(id -u)" != "0" ]; then
   error "❌ Sorry! This script must be run as root."
fi

check_apache2

# Update timezone
setup_log "---> 🕒 Updating packages and setting the timezone."
apt-get update -qq >/dev/null
timedatectl set-timezone $DEFAULT_TIMEZONE

setup_log "---> 🟢 Installing essential programs (git zip unzip curl wget acl)."
apt-get install -y -qq --no-install-recommends git zip unzip curl wget acl apache2-utils

if [ -x "$(command -v docker)" ]; then
    setup_log "---> 🐳 Docker previously installed! Resetting containers, images and networks."
    docker_reset
else
    setup_log "---> 🐳 Installing docker"
    curl -fsSL get.docker.com -o get-docker.sh && sh get-docker.sh
fi

if [ ! -f /usr/local/bin/docker-compose ]; then
  setup_log "---> 📦 Installing docker-compose"
  curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-Linux-x86_64" -o /usr/local/bin/docker-compose
  chmod +x /usr/local/bin/docker-compose

else
    setup_log "---> 📦 Docker-compose previously installed! Skipping..."
fi

# Set root password
setup_log "---> 🔑 Setting the root password"

if [[ -z $ROOT_PASSWORD ]]; then
  passwd
else
  echo $ROOT_PASSWORD | passwd > /dev/null 2>&1
  install_report "---> ROOT_PASSWORD: $ROOT_PASSWORD"
fi

# Creates SSH key from root if one does not exist
if [ ! -e /root/.ssh/id_rsa ]; then
   setup_log "---> 🔑 Creating SSH Keys"

  if [[ -z $SSH_PASSPHRASE ]]; then
    ssh-keygen -q -t rsa -b 4096 -f id_rsa -C "$YOUR_EMAIL" -N ''
  else
    ssh-keygen -q -t rsa -b 4096 -f id_rsa -C "$YOUR_EMAIL" -N "$SSH_PASSPHRASE"
    install_report "---> SSH_PASSPHRASE: $SSH_PASSPHRASE"
  fi
fi

# Create known_hosts file if it doesn't exist
if [ ! -e /root/.ssh/known_hosts ]; then
   setup_log "---> 📄 Creating file known_hosts"
   touch /root/.ssh/known_hosts
fi

# Create authorized_keys file if it doesn't exist
if [ ! -e /root/.ssh/authorized_keys ]; then
  setup_log "---> 📄 Creating file authorized_keys"
  touch /root/.ssh/authorized_keys
fi

# Adds bitbucket.org, gitlab.com, github.com
for S_KEYSCAN in $(echo $SSH_KEYSCAN | sed "s/,/ /g"); do
  setup_log "---> ⚪ Adding $S_KEYSCAN to trusted hosts"
  ssh-keyscan $S_KEYSCAN >> /root/.ssh/known_hosts
done

# Adds standard user, if one does not exist.
if [ `sed -n "/^$DEFAULT_USER/p" /etc/passwd` ]; then
    setup_log "---> 👤 User $DEFAULT_USER already exists. Skipping..."
else
    setup_log "---> 👤 Creating standard user"
    useradd -s /bin/bash -d /home/$DEFAULT_USER -m -U $DEFAULT_USER

    if [[ -z $DEFAULT_USER_PASSWORD ]]; then
      passwd $DEFAULT_USER
    else
      echo $DEFAULT_USER_PASSWORD | passwd $DEFAULT_USER > /dev/null 2>&1
    fi

    # Copy SSH authorized_keys
    setup_log "---> 🗂️ Copying the SSH public key to the home directory of the new default user"
    if [ ! -d /home/$DEFAULT_USER/.ssh ]; then
      mkdir /home/$DEFAULT_USER/.ssh
    fi
    cp -r /root/.ssh/* /home/$DEFAULT_USER/.ssh/
    chown -R $DEFAULT_USER.$DEFAULT_USER /home/$DEFAULT_USER/.ssh

    # add standard user to sudoers
    setup_log "---> 💪 Adding $DEFAULT_USER to sudoers with full privileges"
    echo "$DEFAULT_USER ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/$DEFAULT_USER
    chmod 0440 /etc/sudoers.d/$DEFAULT_USER

    setup_log "---> 🟢 Adding user $DEFAULT_USER to group www-data"
    usermod -aG www-data $DEFAULT_USER

    setup_log "---> 🟢 Adding user $DEFAULT_USER to the docker group"
    usermod -aG docker $DEFAULT_USER
fi


for WORKDIR in $(echo $WORKDIRS | sed "s/,/ /g"); do

  WORKDIR_FULL=${DEFAULT_WORKDIR}/$WORKDIR

  if [ -d $WORKDIR_FULL ]; then
      setup_log "---> 🗑️  Deleting WORKDIR ${WORKDIR} from an unsuccessful previous attempt"
      rm -rf $WORKDIR_FULL
  fi

	setup_log "---> 📂 Creating working directory ${WORKDIR_FULL}"
	mkdir -p $WORKDIR_FULL
done

if $INSTALL_PROXY ; then
    setup_proxy $TEMPLATE
fi

setup_log "---> 🔁 Changing owner of the root working directory to $DEFAULT_USER"
chown -R $DEFAULT_USER.$DEFAULT_USER ${DEFAULT_WORKDIR}

setup_log "---> 🧹 Cleaning up"
apt-get autoremove -y
apt-get clean -y

install_report "Finished on: $(TZ=$DEFAULT_TIMEZONE date)"

if [[ ! -z $WEBHOOK_URL ]]; then
echo -e "🔄 Sending data to the Webhook."
curl --max-time 15 --connect-timeout 60 --silent $WEBHOOK_URL \
-H "Accept: application/json" \
-H "Content-Type: application/json" \
--data @<(cat <<EOF
    {
        "message": "Installation finished",
        "status": "FINISHED",
        "data": {
        "INSTALL_PROXY": "$INSTALL_PROXY",
        "SSH_PASSPHRASE": "$SSH_PASSPHRASE",
        "DEFAULT_TIMEZONE": "$DEFAULT_TIMEZONE",
        "DOCKER_COMPOSE_VERSION": "$DOCKER_COMPOSE_VERSION",
        "ROOT_PASSWORD": "$ROOT_PASSWORD",
        "DEFAULT_USER": "$DEFAULT_USER",
        "DEFAULT_USER_PASSWORD": "$DEFAULT_USER_PASSWORD",

        "WORKDIR": "/home/$DEFAULT_USER",
        "DOCKER_NETWORKS": "$DOCKER_NETWORKS",
        "TEMPLATE": "$TEMPLATE",
        "APP_TEMPLATES": "$APP_TEMPLATES",
        "YOUR_DOMAIN": "$YOUR_DOMAIN",
        "YOUR_EMAIL": "$YOUR_EMAIL",

        "MYSQL_PASSWORD": "$MYSQL_PASSWORD",
        "POSTGRES_PASSWORD": "$POSTGRES_PASSWORD",
        "REDIS_PASSWORD": "$REDIS_PASSWORD",
        "TRAEFIK_PASSWORD": "$TRAEFIK_PASSWORD",
        "TRAEFIK_CREDENTIALS": "$TRAEFIK_CREDENTIALS"
        }
    }
EOF
) > /dev/null 2>&1

fi

# Finish
echo -e "✅ Concluded!"

cat install-report.txt
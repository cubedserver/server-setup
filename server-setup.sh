#!/bin/bash

STARTED_IN=$(TZ=$DEFAULT_TIMEZONE date)

# Example values that will be replaced
EXAMPLE_DOMAIN=yourdomain.local
EXAMPLE_EMAIL=email@yourdomain.local

ROOT_SSH_PASSPHRASE=

# Defaults
: ${TEMPLATE_NGINX_URL:='https://github.com/cubedserver/docker-nginx-proxy/archive/master.zip'}
: ${TEMPLATE_TRAEFIK_URL:='https://github.com/cubedserver/docker-traefik-proxy/archive/master.zip'}

: ${YOUR_DOMAIN:='yourdomain.local'}
: ${YOUR_EMAIL:='email@yourdomain.local'}

: ${DOCKER_COMPOSE_VERSION:='1.29.2'}

: ${SSH_KEYSCAN:='bitbucket.org,gitlab.com,github.com'}
: ${SPACES:='apps,backups'}
: ${TEMPLATE:='nginx'}
: ${APP_TEMPLATES:='portainer,mysql,postgres,redis,adminer,phpmyadmin,whoami'}

: ${DEFAULT_TIMEZONE:='America/Sao_Paulo'}
: ${ROOT_PASSWORD:=$(openssl rand -hex 8)}

: ${DEFAULT_USER:='cubed'}
: ${DEFAULT_USER_PASSWORD:=$(openssl rand -hex 8)}
: ${DEFAULT_WORKDIR:='/home/cubed'}

: ${MYSQL_PASSWORD:=$(openssl rand -hex 8)}
: ${POSTGRES_PASSWORD:=$(openssl rand -hex 8)}
: ${REDIS_PASSWORD:=$(openssl rand -hex 8)}
: ${TRAEFIK_PASSWORD:=$(openssl rand -hex 8)}

: ${FORCE_INSTALL:=false}
: ${SWARM_MODE:=false}
: ${IP_ADRESS:=$(curl checkip.amazonaws.com)}

: ${INSTALL_PROXY:=false}

WEBHOOK_URL=

usage() {
    set +x
    cat 1>&2 <<HERE
Script for initial configurations of Docker, Docker Swarm, Docker Compose and Reverse Proxy.
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
--root-ssh-passphrase       Provides a passphrase for the ssh key
--ssh-passphrase            Provides a passphrase for the ssh key
-f|--force                  Force install/re-install

OPTIONS (Docker Swarm):
-s|--swarm-mode             Run Docker Engine in swarm mode
--advertise-addr            Advertised address (format: <ip|interface>[:port])

OPTIONS (Proxy Settings):
-b|--proxy-template         Proxy templates to be installed. Currently traefik and nginx are available
-a|--app-templates          Additional applications that will be installed along with the proxy
-d|--domain                 If you have configured your DNS and pointed A records to this host, this will be the domain used to access the services
                            After everything is set up, you can access the services as follows: service.yourdomain.local
-e|--email                  Email that Let's Encrypt will use to generate SSL certificates

OPTIONS (Service Credentials):
--mysql-password            MySQL root password
--postgres-password         PostgreSQL password
--redis-password            Redis password
--traefik-password          Traefik admin password  

OPTIONS (Webhook):
--webhook-url               Ping URL with provisioning updates
HERE
}

POSITIONAL=()
while [[ $# -gt 0 ]]; do
    key="$1"

    case $key in
    -h | --help)
        usage
        exit 0
        ;;

    -f | --force)
        FORCE_INSTALL=true
        shift 1
        ;;

    -s | --swarm-mode)
        SWARM_MODE=true
        shift 1
        ;;

    --root-ssh-passphrase)
        ROOT_SSH_PASSPHRASE="$2"
        shift 2
        ;;

    --advertise-addr)
        IP_ADRESS="$2"
        shift 2
        ;;

    -t | --timezone)
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

    --ssh-passphrase)
        USER_SSH_PASSPHRASE="$2"
        shift 2
        ;;

    --workdir)
        DEFAULT_WORKDIR="$2"
        shift 2
        ;;

    --spaces)
        SPACES="$2"
        shift 2
        ;;

    -b | --proxy-template)
        TEMPLATE="$2"
        INSTALL_PROXY=true
        shift 2
        ;;

    -a | --app-templates)
        APP_TEMPLATES="$2"
        shift 2
        ;;

    -d | --domain)
        YOUR_DOMAIN="$2"
        shift 2
        ;;

    -e | --email)
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

    *)                     # unknown option
        POSITIONAL+=("$1") # save it in an array for later
        echo "Parameter not known: $1"
        exit 1
        ;;
    esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

check_apache2() {
    if dpkg -l | grep -q apache2-bin; then
        error "You must uninstall the Apache2 server first."
    fi
}

# Ping URL With Provisioning Updates
function provision_ping {
    if [[ ! -z $WEBHOOK_URL ]]; then
        curl --max-time 15 --connect-timeout 60 --silent $WEBHOOK_URL \
            -H "Accept: application/json" \
            -H "Content-Type: application/json" \
            --data "{\"message\":\"$1\",\"status\":\"IN_PROGRESS\"}" >/dev/null 2>&1
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
    if [ ! -d /var/.server-setup ]; then
        mkdir -p /var/.server-setup
    fi

    echo $* >>/var/.server-setup/install-report.txt
}

function create_docker_network() {
    NETWORK_NAME=$1
    setup_log "---> ⚡ Creating Docker network $NETWORK_NAME"
    docker network ls | grep $NETWORK_NAME >/dev/null || docker network create $NETWORK_NAME
}

function ssh_keygen() {
    # $1 email $2 ssh_passphrase $3 path
    ssh-keygen -q -t rsa -b 4096 -f $3 -C "$1" -N "$2" >/dev/null 2>&1
}

# Remove images, volumes and containers from a previous unsuccessful attempt
function docker_reset() {
    setup_log "---> 🐳 Docker previously installed!"

    if $FORCE_INSTALL; then

        setup_log "---> 🔥 Resetting containers, images and networks."

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

    else
        setup_log "---> 🐳 Skipping Docker Installation."
    fi

}

function docker_compose_install() {
    setup_log "---> 📦 Installing docker-compose"
    curl -L "https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_VERSION/docker-compose-Linux-x86_64" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
}

function setup_proxy() {
    TEMPLATE=$1

    if [ $TEMPLATE == "nginx" ]; then
        TEMPLATE_URL=$TEMPLATE_NGINX_URL
        ORIGINAL_NAME=docker-nginx-proxy
        DIR_NAME=nginx-proxy
        DOCKER_NETWORKS='nginx-proxy,internal'
    else
        TEMPLATE_URL=$TEMPLATE_TRAEFIK_URL
        ORIGINAL_NAME=docker-traefik-proxy
        DIR_NAME=traefik-proxy
        DOCKER_NETWORKS='web,internal'

        TRAEFIK_CREDENTIALS=$(htpasswd -nbB admin "$TRAEFIK_PASSWORD" | sed -e s/\\$/\\$\\$/g)
    fi

    FILE_ZIPED="$ORIGINAL_NAME.zip"
    WORKDIR="$DEFAULT_WORKDIR/apps"

    if [ -d "$DEFAULT_WORKDIR/apps" ]; then
        if $FORCE_INSTALL; then
            setup_log "---> 🔥 Deleting previous files from an unsuccessful previous attempt"
            rm -rf "$DEFAULT_WORKDIR/apps/*"
        else
            setup_log "---> 📂 Skipping existing $DEFAULT_WORKDIR/apps working directory for $TEMPLATE proxy"
        fi
    else
        setup_log "---> 📂 Creating working directory $DEFAULT_WORKDIR/apps for the $TEMPLATE Proxy"
        mkdir -p "$DEFAULT_WORKDIR/apps"
    fi

    PROXY_FULL_PATH="$DEFAULT_WORKDIR/apps/$DIR_NAME"

    setup_log "---> 📥 Downloading template $TEMPLATE"
    wget -q $TEMPLATE_URL -O $FILE_ZIPED

    if [ ! -f $FILE_ZIPED ]; then
        setup_log "---> ❌ Failed to download proxy files. Skipping..."
    else
        setup_log "---> 🗃️ Extracting files from $FILE_ZIPED"
        unzip -q $FILE_ZIPED && rm $FILE_ZIPED && mv "$ORIGINAL_NAME-master" $PROXY_FULL_PATH

        if [[ ! -z $YOUR_EMAIL ]]; then
            setup_log "---> 📧 Overriding $EXAMPLE_EMAIL to $YOUR_EMAIL email from configuration files"
            find $PROXY_FULL_PATH -type f -exec sed -i "s/$EXAMPLE_EMAIL/$YOUR_EMAIL/g" {} \;
            install_report "---> EXAMPLE_EMAIL: $EXAMPLE_EMAIL"
        fi

        if [[ ! -z $YOUR_DOMAIN ]]; then
            setup_log "---> 🌐 Overriding $EXAMPLE_DOMAIN to $YOUR_DOMAIN domain for configuration files"
            find $PROXY_FULL_PATH -type f -exec sed -i "s/$EXAMPLE_DOMAIN/$YOUR_DOMAIN/g" {} \;
            install_report "---> YOUR_DOMAIN: $YOUR_DOMAIN"
        fi

        # Update service credentials

        if [[ ! -z $MYSQL_PASSWORD && -e $PROXY_FULL_PATH/templates/mysql/docker-compose.yml ]]; then
            setup_log "---> 🔄 Updating MySQL password"
            sed -i "s/your_secure_password/$MYSQL_PASSWORD/g" $PROXY_FULL_PATH/templates/mysql/docker-compose.yml
            install_report "---> MYSQL_PASSWORD: $MYSQL_PASSWORD"
        fi

        if [[ ! -z $POSTGRES_PASSWORD && -e $PROXY_FULL_PATH/templates/templates/docker-compose.yml ]]; then
            setup_log "---> 🔄 Updating PostgreSQL password"
            sed -i "s/your_secure_password/$POSTGRES_PASSWORD/g" $PROXY_FULL_PATH/templates/postgres/docker-compose.yml
            install_report "---> POSTGRES_PASSWORD: $POSTGRES_PASSWORD"
        fi

        if [[ ! -z $REDIS_PASSWORD && -e $PROXY_FULL_PATH/templates/redis/docker-compose.yml ]]; then
            setup_log "---> 🔄 Updating Redis password"
            sed -i "s/your_secure_password/$REDIS_PASSWORD/g" $PROXY_FULL_PATH/templates/redis/docker-compose.yml
            install_report "---> REDIS_PASSWORD: $REDIS_PASSWORD"
        fi

        if [[ ! -z $TRAEFIK_CREDENTIALS && -e "$PROXY_FULL_PATH/docker-compose.yml" ]]; then
            setup_log "---> 🔄 Updating Traefik password"

            OLD_TRAEFIK_CREDENTIALS='admin:$$2y$$05$$IbYykP9bwz8PAhYBxvDkAOdEwMkMvdUvE86OO8EcEAp16Otddn4a6'
            sed -i "s/$OLD_TRAEFIK_CREDENTIALS/$TRAEFIK_CREDENTIALS/g" "$PROXY_FULL_PATH/docker-compose.yml"
            install_report "---> TRAEFIK_PASSWORD: $TRAEFIK_PASSWORD"

            if [[ ! -e "$PROXY_FULL_PATH/acme.json" ]]; then
                setup_log "---> 📄 Creating Traefik acme.json file"
                touch "$PROXY_FULL_PATH/acme.json"
            fi

            chmod 600 "$PROXY_FULL_PATH/acme.json"
        fi

        for NETWORK_NAME in $(echo $DOCKER_NETWORKS | sed "s/,/ /g"); do
            create_docker_network $NETWORK_NAME
        done

        setup_log "---> ⚡ Starting reverse proxy containers"
        docker-compose -f "$PROXY_FULL_PATH/docker-compose.yml" up -d

        install_report "Services started"
        install_report "$PROXY_FULL_PATH/docker-compose.yml"

        # Moves the app folder to the working directory root
        if [[ ! -z $APP_TEMPLATES ]]; then
            for APP in $(echo $APP_TEMPLATES | sed "s/,/ /g"); do
                if [ -d "$PROXY_FULL_PATH/templates/$APP" ]; then
                    mv "$PROXY_FULL_PATH/templates/$APP" "$DEFAULT_WORKDIR/apps/$APP"

                    setup_log "---> ⚡ Starting $APP container"
                    docker-compose -f "$DEFAULT_WORKDIR/apps/$APP/docker-compose.yml" up -d
                    install_report "$DEFAULT_WORKDIR/apps/$APP/docker-compose.yml"
                else
                    setup_log "---> ❌ App $APP files not found. Skipping..."
                fi
            done
        fi
    fi
}

if [ "$(id -u)" != "0" ]; then
    error "❌ Sorry! This script must be run as root."
fi

if [ -f /var/.server-setup/installed ]; then

    if $FORCE_INSTALL; then
        rm -rf /var/.server-setup
    else
        error "❌ This server has already been configured. See /var/.server-setup/install-report.txt for details."
    fi
fi

check_apache2

# Update timezone
setup_log "---> 🔄 Updating packages and setting the timezone."
apt-get update -qq >/dev/null
timedatectl set-timezone $DEFAULT_TIMEZONE

setup_log "---> 🔄 Installing essential programs (git zip unzip curl wget acl apache2-utils)."
apt-get install -y -qq --no-install-recommends git zip unzip curl wget acl apache2-utils

if [ -x "$(command -v docker)" ]; then
    docker_reset
else
    setup_log "---> 🐳 Installing docker"
    curl -fsSL get.docker.com -o get-docker.sh && sh get-docker.sh

    if $SWARM_MODE; then
        setup_log "---> 🔄 Starting Swarm Mode"
        SWARM_LOG=`docker swarm init --advertise-addr $IP_ADRESS`
        SWARM_TOKEN_MANAGER=`docker swarm join-token manager`
        SWARM_TOKEN_WORKER=`docker swarm join-token worker`
    fi
fi

if [ ! -f /usr/local/bin/docker-compose ]; then
    docker_compose_install
else
    setup_log "---> 📦 Docker-compose previously installed!"
    if $FORCE_INSTALL; then

        setup_log "---> 📦 Removing previous Docker Compose installation"
        rm /usr/local/bin/docker-compose

        docker_compose_install
    else
        setup_log "---> 📦 Skipping Docker Compose installation..."
    fi
fi

# Set root password
setup_log "---> 🔑 Setting the root password"

if [[ -z $ROOT_PASSWORD ]]; then
    passwd
else
    echo $ROOT_PASSWORD | passwd >/dev/null 2>&1
    install_report "---> ROOT_PASSWORD: $ROOT_PASSWORD"
fi

# Creates SSH key from root if one does not exist
if [ ! -e /root/.ssh/id_rsa ]; then
    setup_log "---> 🔑 Creating the root user's SSH key"

    ssh_keygen "root" "$ROOT_SSH_PASSPHRASE" "/root/.ssh/id_rsa"
    install_report "---> ROOT_SSH_PASSPHRASE: $ROOT_SSH_PASSPHRASE"
else
    if $FORCE_INSTALL; then
        setup_log "---> 🔑 Recreating the root user's SSH key"
        rm /root/.ssh/*
        ssh_keygen "root" "$ROOT_SSH_PASSPHRASE" "/root/.ssh/id_rsa"
        install_report "---> ROOT_SSH_PASSPHRASE: $ROOT_SSH_PASSPHRASE"
    else
        setup_log "---> 🔑 Ignoring the existing root user's SSH key"
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
    setup_log "---> 🔄 Adding $S_KEYSCAN to trusted hosts"
    ssh-keyscan $S_KEYSCAN >>/root/.ssh/known_hosts
done

# Adds standard user, if one does not exist.
if [ $(sed -n "/^$DEFAULT_USER/p" /etc/passwd) ]; then
    setup_log "---> 👤 User $DEFAULT_USER already exists. Skipping..."
else
    setup_log "---> 👤 Creating standard user $DEFAULT_USER"
    useradd -s /bin/bash -d $DEFAULT_WORKDIR -m -U $DEFAULT_USER

    if [[ -z $DEFAULT_USER_PASSWORD ]]; then
        passwd $DEFAULT_USER
    else
        echo $DEFAULT_USER_PASSWORD | passwd $DEFAULT_USER >/dev/null 2>&1
    fi

    if [ ! -d $DEFAULT_WORKDIR/.ssh ]; then
        mkdir $DEFAULT_WORKDIR/.ssh
    fi

    cp /root/.ssh/known_hosts $DEFAULT_WORKDIR/.ssh/known_hosts
    cp /root/.ssh/authorized_keys $DEFAULT_WORKDIR/.ssh/authorized_keys

    setup_log "---> 🔑 Creating the $DEFAULT_USER user's SSH Keys"
    ssh_keygen "$DEFAULT_USER" "$USER_SSH_PASSPHRASE" "$DEFAULT_WORKDIR/.ssh/id_rsa"

    chown -R $DEFAULT_USER.$DEFAULT_USER $DEFAULT_WORKDIR/.ssh

    setup_log "---> 💪 Adding $DEFAULT_USER to sudoers with full privileges"
    echo "$DEFAULT_USER ALL=(ALL:ALL) NOPASSWD: ALL" >/etc/sudoers.d/$DEFAULT_USER
    chmod 0440 /etc/sudoers.d/$DEFAULT_USER

    setup_log "---> 🔄 Adding user $DEFAULT_USER to the docker group"
    usermod -aG docker $DEFAULT_USER

    setup_log "---> 🔄 Adding user $DEFAULT_USER to group www-data"
    usermod -aG www-data $DEFAULT_USER
fi

for SPACE in $(echo $SPACES | sed "s/,/ /g"); do
    if [ -d "$DEFAULT_WORKDIR/$SPACE" ]; then

        if $FORCE_INSTALL; then
            setup_log "---> 🔥 Deleting WORKDIR $SPACE from an previous attempt"
            rm -rf "$DEFAULT_WORKDIR/$SPACE/*"
        else
            setup_log "---> 📂 Skipping files from previous installation: $DEFAULT_WORKDIR/$SPACE"
        fi
    else
        setup_log "---> 📂 Creating working directory: $DEFAULT_WORKDIR/$SPACE"
        mkdir -p "$DEFAULT_WORKDIR/$SPACE"
    fi
done

if $INSTALL_PROXY; then
    setup_proxy $TEMPLATE
fi

setup_log "---> 🧹 Cleaning up"
apt-get autoremove -y
apt-get clean -y

setup_log "---> 🔁 Changing owner of the root working directory to $DEFAULT_USER"
chown -R $DEFAULT_USER.$DEFAULT_USER $DEFAULT_WORKDIR

if [[ ! -z $WEBHOOK_URL ]]; then
    echo -e "🔄 Sending data to the Webhook."
    curl --max-time 15 --connect-timeout 60 --silent $WEBHOOK_URL \
        -H "Accept: application/json" \
        -H "Content-Type: application/json" \
        --data @<(
            cat <<EOF
    {
        "message": "Installation finished",
        "status": "FINISHED",
        "data": {
            "ROOT_SSH_PASSPHRASE": "$ROOT_SSH_PASSPHRASE",
            "USER_SSH_PASSPHRASE": "$USER_SSH_PASSPHRASE",
            "DEFAULT_TIMEZONE": "$DEFAULT_TIMEZONE",
            "DOCKER_COMPOSE_VERSION": "$DOCKER_COMPOSE_VERSION",
            "ROOT_PASSWORD": "$ROOT_PASSWORD",
            "DEFAULT_USER": "$DEFAULT_USER",
            "DEFAULT_USER_PASSWORD": "$DEFAULT_USER_PASSWORD",

            "WORKDIR": "$DEFAULT_WORKDIR",
            "DOCKER_NETWORKS": "$DOCKER_NETWORKS",
            "TEMPLATE": "$TEMPLATE",
            "APP_TEMPLATES": "$APP_TEMPLATES",
            "YOUR_DOMAIN": "$YOUR_DOMAIN",
            "YOUR_EMAIL": "$YOUR_EMAIL",

            "SWARM_MODE": "$SWARM_MODE",
            "SWARM_LOG":  "$SWARM_LOG",            
            "SWARM_TOKEN_MANAGER": "$SWARM_TOKEN_MANAGER",
            "SWARM_TOKEN_WORKER": "$SWARM_TOKEN_WORKER",

            "IP_ADRESS": "$IP_ADRESS",

            "MYSQL_PASSWORD": "$MYSQL_PASSWORD",
            "POSTGRES_PASSWORD": "$POSTGRES_PASSWORD",
            "REDIS_PASSWORD": "$REDIS_PASSWORD",
            "TRAEFIK_PASSWORD": "$TRAEFIK_PASSWORD"
        }
    }
EOF
        ) >/dev/null 2>&1

fi

# Finish
echo -e "✅ Concluded!"

FINISHED_ON=$(TZ=$DEFAULT_TIMEZONE date)

install_report "Started in: $STARTED_IN"
install_report "Finished in: $FINISHED_ON"

echo $FINISHED_ON >/var/.server-setup/installed

echo -e "📈 Install Report: /var/.server-setup/install-report.txt"
cat /var/.server-setup/install-report.txt

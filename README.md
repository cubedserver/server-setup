# Server Setup

<div align="center">
  <img src="cover.svg" loading="lazy" />
</div>

Script to make initial configurations of Docker, Docker Compose and Reverse Proxy (Traefik or NGINX) on servers in Digital Ocean, Linone, AWS EC2 or similar.

Performs the following configuration steps:

* Definition of timezone
* root user settings
* Adds new default user for full privilege deploy
* Install git, zip, unzip, curl, acl, docker and docker-compose
* Adds github, gitlab and bitbucket to trusted hosts

Tested on a VPS running Ubuntu Server 20.04 LTS with 4GB RAM, but can be used in similar distributions.

## Installation

To do the setup, download and run the script `server-setup.sh` or if you prefer (proceed at your own risk), execute the instruction below.

## Installation

Basic installation with NGINX as default
~~~
wget -qO- https://raw.githubusercontent.com/cubedserver/server-setup/master/server-setup.sh | bash -s -- \
--proxy-template nginx \
--app-templates mysql,postgres,redis,whoami,adminer,phpmyadmin,portainer \
--domain example.com \
--email email@example.com
~~~

Basic installation with TRAEFIK as default
~~~
wget -qO- https://raw.githubusercontent.com/cubedserver/server-setup/master/server-setup.sh | bash -s -- \
--proxy-template traefik \
--app-templates mysql,postgres,redis,whoami,adminer,phpmyadmin,portainer \
--domain example.com \
--email email@example.com
~~~

## Command options

You can get help by passing the `-h` option.

~~~
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
--root-ssh-passphrase       Provides a passphrase for the ssh key
--ssh-passphrase            Provides a passphrase for the ssh key
-b|--proxy-template         Proxy templates to be installed. Currently traefik and nginx are available
-a|--app-templates          Additional applications that will be installed along with the proxy
-d|--domain                 If you have configured your DNS and pointed A records to this host, this will be the domain used to access the services
                            After everything is set up, you can access the services as follows: service.yourdomain.local
-e|--email                  Email that Let's Encrypt will use to generate SSL certificates
-f|--force                  Force install/re-install

OPTIONS (Service Credentials):
--mysql-password            MySQL root password
--postgres-password         PostgreSQL password
--redis-password            Redis password
--traefik-password          Traefik admin password  

OPTIONS (Webhook):
--webhook-url               Ping URL with provisioning updates
~~~

## Important
In order for you to be able to deploy applications using git and some deployment tools such as the [deployer](https://deployer.org/), you will need to add the public key (id_rsa.pub) of the user created on your VCS server (bitbucket, gitlab, github, etc.).

## Tips

To not have to enter the password every time you need to access the remote server by SSH or have to do some deploy, type the command below. This will add your public key to the new user's ```authorized_keys``` file.

```
ssh-copy-id <USERNAME>@<SERVER IP>
```

### Reverse Proxy

If you are looking for a template for fast configuration of docker containers for reverse proxy, automatic configuration of virtualhosts and generation of SSL certificates with Let's Encrypt, see the repositories:

 * [cubedserver/docker-traefik-proxy](https://github.com/cubedserver/docker-traefik-proxy)

 * [cubedserver/docker-nginx-proxy](https://github.com/cubedserver/docker-nginx-proxy)

## Contributing

1. Fork this repository!
2. Create your feature from the **develop** branch: git checkout -b feature/my-new-feature
3. Write and comment your code
4. Commit your changes: `git commit -am 'Add some feature'`
5. Push the branch: `git push origin feature/my-new-feature`
6. Make a pull request to the branch **develop**

## Credits

* [Fábio Assunção](https://github.com/fabioassuncao)
* [All Contributors](../../contributors)


## License

Licensed under the MIT License.

# Basic Host Setup

Super basic script for lazy devs to do initial server configurations on DigitalOcean, Linone, AWS EC2 or similar.

Performs the following configuration steps:

* Definition of timezone
* root user settings
* Adds new default user for full privilege deploy
* Install git, zip, unzip, curl, acl, docker and docker-compose
* Adds github, gitlab and bitbucket to trusted hosts

Tested on a VPS running Ubuntu Server 20.04 LTS with 4GB RAM, but can be used in similar distributions.

## Installation

```
curl -fsSL https://git.io/fpgbw -o setup-vps.sh && bash setup-vps.sh
```

## Important
In order for you to be able to deploy applications using git and some deployment tools such as the [deployer](https://deployer.org/), you will need to add the public key (id_rsa.pub) of the user created on your VCS server (bitbucket, gitlab, github, etc.).

## Tips

To not have to enter the password every time you need to access the remote server by SSH or have to do some deploy, type the command below. This will add your public key to the new user's ```authorized_keys``` file.

```
ssh-copy-id <USERNAME>@<SERVER IP>
```

### Reverse Proxy

If you are looking for a boilerplate for fast configuration of docker containers for reverse proxy, automatic configuration of virtualhosts and generation of SSL certificates with Let's Encrypt, see the repositories:

 * [fabioassuncao/docker-boilerplate-traefik-proxy](https://github.com/fabioassuncao/docker-boilerplate-traefik-proxy)

 * [fabioassuncao/docker-boilerplate-nginx-proxy](https://github.com/fabioassuncao/docker-boilerplate-nginx-proxy)

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
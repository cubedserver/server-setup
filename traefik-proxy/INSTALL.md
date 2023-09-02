# Install Traefik
Please note that [Traefik](https://traefik.io/) will need to be deployed on a manager node on your swarm. You'll also need to make sure that your firewall on this node is correctly setup to allow both port 80 and 443 (http / https) from outside. This is important because Traefik will listen on these ports for incoming traffic.

The first thing before creating the config file is to create a docker swarm network that will be used by Traefik to watch for services to expose. 

This can be done in one command:

```console
docker network create --driver=overlay traefik-public
```

This will create an [overlay network](https://docs.docker.com/network/overlay/) named 'traefik-public' on the swarm.

Now we are going to create the docker compose file to deploy Traefik.

```console
version: '3'

services:
  reverse-proxy:
    image: traefik:v2.0.2
    command:
      - "--providers.docker.endpoint=unix:///var/run/docker.sock"
      - "--providers.docker.swarmMode=true"
      - "--providers.docker.exposedbydefault=false"
      - "--providers.docker.network=traefik-public"
      - "--entrypoints.web.address=:80"
    ports:
      - 80:80
    volumes:
      # So that Traefik can listen to the Docker events
      - /var/run/docker.sock:/var/run/docker.sock:ro
    networks:
      - traefik-public
    deploy:
      placement:
        constraints:
          - node.role == manager

networks:
  traefik-public:
    external: true
```

This is the minimal amount of config needed to deploy a working Traefik instance.

This configuration is enough to get started. You can deploy Traefik using the following command:

```console
docker stack deploy traefik -c traefik.yaml
```

# Deploy and expose a hello-world container

Now it's time to deploy something on your swarm to test the configuration. 

For this example we are going to deploy tutum/hello-world a little container with an apache service that display an "Hello World" page.

```console
version: '3'
services:
  helloworld:
    image: tutum/hello-world:latest
    networks:
     - traefik-public
    deploy:
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.helloworld.rule=Host(`helloworld.local`)"
        - "traefik.http.routers.helloworld.entrypoints=web"
        - "traefik.http.services.helloworld.loadbalancer.server.port=80"
networks:
  traefik-public:
    external: true
```

The labels sections is read by Traefik to get the configuration of the container and to create the needed components to expose it.

Now if you access the page at http://localhost you'll be redirect to Traefik that will proxify the content of the helloworld container.

# Add HTTPS support
If you have followed you should now have a working Traefik instance and a helloworld service running and accessible on http://localhost. 

This is working but not secure, you should always use HTTPS when possible. Thankfully this can be done easily in Traefik.

In this we are going to use the [HTTP challenge](https://letsencrypt.org/docs/challenge-types/) to automatically generate a Letsencrypt certificate.

I won't go in the details to explain how the HTTP-01 challenge work, but basically all you have to do is update the A record of your DNS zone to point to your docker swarm manager IP address. (where Traefik is exposed).

```console
version: '3'

services:
  reverse-proxy:
    image: traefik:v2.0.2
    command:
      - "--providers.docker.endpoint=unix:///var/run/docker.sock"
      - "--providers.docker.swarmMode=true"
      - "--providers.docker.exposedbydefault=false"
      - "--providers.docker.network=traefik-public"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
      - "--certificatesresolvers.letsencryptresolver.acme.httpchallenge=true"
      - "--certificatesresolvers.letsencryptresolver.acme.httpchallenge.entrypoint=web"
      - "--certificatesresolvers.letsencryptresolver.acme.email=user@domaine.com"
      - "--certificatesresolvers.letsencryptresolver.acme.storage=/letsencrypt/acme.json"
    ports:
      - 80:80
      - 443:443
    volumes:
      # To persist certificates
      - traefik-certificates:/letsencrypt
      # So that Traefik can listen to the Docker events
      - /var/run/docker.sock:/var/run/docker.sock:ro
    networks:
      - traefik-public
    deploy:
      placement:
        constraints:
          - node.role == manager
volumes:
  traefik-certificates:

networks:
  traefik-public:
    external: true
```

# Update hello-world to use HTTPS config
Now we are going to update the hello-world deployment configuration file in order to expose it using HTTPS.

```console
version: '3'
services:
  helloworld:
    image: tutum/hello-world:latest
    networks:
     - traefik-public
    deploy:
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.helloworld.rule=Host(`helloworld.local`)"
        - "traefik.http.routers.helloworld.entrypoints=websecure"
        - "traefik.http.services.helloworld.loadbalancer.server.port=80"
networks:
  traefik-public:
    external: true
```

Of course this example won't work since you cannot proove that you own the helloworld.local domain. (.local is a reserved TLD used for local area network)

# Create an automatic HTTPS redirect
If you want to redirect all HTTP traffic to HTTPS it can be done by easily by using a Middleware. 

Just add the following command line argument to the configuration file

```console
- "traefik.http.routers.http-catchall.rule=hostregexp(`{host:.+}`)"
- "traefik.http.routers.http-catchall.entrypoints=web"
- "traefik.http.routers.http-catchall.middlewares=redirect-to-https@docker"
- "traefik.http.middlewares.redirect-to-https.redirectscheme.scheme=https"
```

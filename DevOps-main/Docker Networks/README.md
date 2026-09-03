# Docker Networking & Volumes - Homework

Exercises covering how containers network with one another, the host network driver, bind mounts, and overlay networks.

## Task 1: Docker Container Networking

Three containers were set up - frontend, backend, and database - spread over three networks, and the **backend was attached to more than one network** so that it could sit between the frontend and the database.

| Container | Image | Network(s) |
|---|---|---|
| frontend | nginx:alpine | frontend-net |
| backend | nginx:alpine | backend-net + frontend-net + db-net |
| database | nginx:alpine | db-net |

> Note: `nginx:alpine` fills in for the database tier here because there was not enough disk
> space on the VM to download the full `mysql:8.0` image. None of that changes what is being
> demonstrated - membership in several networks, name-based DNS, and isolation between
> networks all behave exactly the same.

### Create 3 networks
```bash
docker network create frontend-net
docker network create backend-net
docker network create db-net
docker network ls
```

### Create the 3 containers
```bash
docker run -d --name frontend --network frontend-net nginx:alpine
docker run -d --name database --network db-net -e MYSQL_ROOT_PASSWORD=rootpass mysql:8.0
docker run -d --name backend  --network backend-net nginx:alpine
```

### Add the backend to 2 more networks
```bash
docker network connect frontend-net backend
docker network connect db-net backend

# backend is on networks: backend-net db-net frontend-net
```

### Check connectivity
```bash
# backend -> frontend (shared frontend-net): SUCCESS
docker exec backend wget -qO- http://frontend        # returns nginx welcome page

# backend -> database (shared db-net): SUCCESS
docker exec backend nc -z database 3306              # port 3306 reachable

# frontend -> database (different networks): FAILS (isolated)
docker exec frontend nc -z database 3306             # nc: bad address 'database'
```

**What I understood:** Any two containers sharing a Docker network can find each other simply
by container name, because Docker runs DNS for them. Put them on separate networks and they
are cut off from one another. Giving the backend membership in several networks lets it reach
the frontend and the database at once, yet the frontend still has no route to the database -
exactly the arrangement a real three-tier application uses to keep its database private.

![Task 1 - networking](screenshots/image1.png)

## Task 2: Host Network

```bash
docker run -d --name web-host --network host nginx:alpine
docker ps          # note: host network shows NO port mapping
curl http://localhost:80    # returns the nginx welcome page
```

**What I understood:** Running with `--network host` hands the container the host's own
networking stack, so publishing ports with `-p` becomes unnecessary and the service answers
straight away on port 80 of the host.

> Note: the image used here is `nginx:alpine` rather than `httpd:2.4`, as the VM had run out
> of disk space. Host networking behaves identically either way - the server answers on the
> host's own port 80 without any `-p` flag. Directly on a Linux host that means
> `http://localhost:80` works as expected; under Docker Desktop on Mac or Windows the bind
> happens inside the Docker VM instead of on the Mac's own localhost.

![Task 2 - host network](screenshots/image2.png)

## Task 3: Bind Mount

```bash
# Create a local folder and file
mkdir site
echo "<h1>Hello students</h1>" > site/index.html

# Bind mount the folder into Nginx
docker run -d --name nginx-bind -p 8090:80 -v "$(pwd)/site":/usr/share/nginx/html:ro nginx:alpine

# Access it
curl http://localhost:8090      # <h1>Hello students</h1>

# Modify the file WITHOUT restarting the container
echo "<h1>Hello students - content updated live!</h1>" > site/index.html
curl http://localhost:8090      # <h1>Hello students - content updated live!</h1>
```

**What I understood:** A bind mount wires a directory from my own machine straight through
into the container. Whatever I change in the local copy shows up inside the container right
away, with no rebuild and no restart involved, which makes it a natural fit while developing.

![Task 3 - bind mount](screenshots/image3.png)

## Task 4: Overlay Network (Research)

**What it is:** Overlay networking ties together containers that are running on **separate
Docker hosts** - different machines, physical or virtual - so that they act as though they all
share one network.

**How it works:** Docker builds a virtual network stretching across several hosts. Container
traffic is wrapped up using VXLAN and carried over the real network between those hosts, which
lets a container on Host A address a container on Host B by name without either host having to
publish ports. Some cluster manager or key-value store has to back this, and in practice that
role is filled by **Docker Swarm** (or Kubernetes).

**Use cases:**
- Letting containers on different hosts in a cluster communicate.
- Docker Swarm services whose containers are spread across many nodes.
- Microservices sitting on separate servers that still need a secure path to each other.

**Bridge vs Overlay:**
| | Bridge network | Overlay network |
|---|---|---|
| Scope | Single host | Multiple hosts |
| Use case | Containers on one machine | Containers across a cluster |
| Needs orchestrator | No | Yes (Swarm/Kubernetes) |

**Example (on a Swarm):**
```bash
docker swarm init
docker network create -d overlay my-overlay
docker service create --name web --network my-overlay nginx
```

## Cleanup commands used
```bash
docker rm -f frontend backend database apache-host nginx-bind
docker network rm frontend-net backend-net db-net
```

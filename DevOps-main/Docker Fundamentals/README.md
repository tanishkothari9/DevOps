# Docker Fundamentals - Hello World Applications

A set of six minimal "Hello World" programs, every one of them packaged into its own container image with a dedicated Dockerfile.

## Folder structure
```
Docker Fundamentals/
├── nodejs-app/     Node.js (built-in http server)
├── python-app/     Python (Flask)
├── java-app/       Java (built-in HttpServer)
├── Apache-app/     Apache HTTP Server (static page)
├── React-app/      React (built + served by Nginx)
└── nginx-app/      Nginx (static page)
```

## Ports summary
| App | Container port | Example run command |
|---|---|---|
| nodejs-app | 3000 | `docker run -p 3000:3000 nodejs-app` |
| python-app | 5000 | `docker run -p 5000:5000 python-app` |
| java-app | 8080 | `docker run -p 8080:8080 java-app` |
| Apache-app | 80 | `docker run -p 8081:80 apache-app` |
| React-app | 80 | `docker run -p 8082:80 react-app` |
| nginx-app | 80 | `docker run -p 8083:80 nginx-app` |

## Build and run each app
Each block below is meant to be executed from within the matching application folder.

### nodejs-app
```bash
cd nodejs-app
docker build -t nodejs-app .
docker run -d -p 3000:3000 nodejs-app
# open http://localhost:3000
```

### python-app
```bash
cd python-app
docker build -t python-app .
docker run -d -p 5000:5000 python-app
# open http://localhost:5000
```

### java-app
```bash
cd java-app
docker build -t java-app .
docker run -d -p 8080:8080 java-app
# open http://localhost:8080
```

### Apache-app
```bash
cd Apache-app
docker build -t apache-app .
docker run -d -p 8081:80 apache-app
# open http://localhost:8081
```

### React-app
```bash
cd React-app
docker build -t react-app .
docker run -d -p 8082:80 react-app
# open http://localhost:8082
```

### nginx-app
```bash
cd nginx-app
docker build -t nginx-app .
docker run -d -p 8083:80 nginx-app
# open http://localhost:8083
```

## Useful Docker commands
```bash
docker images            # list built images
docker ps                # list running containers
docker stop <container>  # stop a container
docker rm <container>    # remove a container
docker logs <container>  # view container logs
```

## Screenshots
For each application, include a capture of "Hello World" rendered in the browser alongside the terminal output from building and running it.

- Node.js: ![nodejs](screenshots/nodejs.png)
- Python: ![python](screenshots/python.png)
- Java: ![java](screenshots/java.png)
- Apache: ![apache](screenshots/apache.png)
- React: ![react](screenshots/react.png)
- Nginx: ![nginx](screenshots/nginx.png)

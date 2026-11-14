# VProfile – Installation and Deployment Guide

This document describes the installation, configuration, containerization, and deployment of the VProfile multi-tier Java application using Docker Compose and Harbor Private Container Registry.

The deployment consists of five services:

- Nginx – Reverse proxy
- Apache Tomcat – Java application server
- MySQL – Relational database
- RabbitMQ – Message broker
- Memcached – Caching service

---

## 1. Prerequisites

Prepare a Linux machine with:

| Component | Requirement |
|---|---|
| Operating system | Linux |
| Docker Engine | Installed and running |
| Docker Compose | Docker Compose plugin |
| Git | Installed |
| Harbor | Private registry, configured and accessible |
| Network | Docker bridge networking |

The project also requires access to the VProfile source code and its SQL database dump.

## 2. Project Configuration

Clone or copy the VProfile project into your working directory.

```bash
git clone <YOUR-REPOSITORY-URL>
cd vprofile-project
```

Check the project files:

```bash
ls -la
```

Example project structure:

```text
vprofile-project/
│
├── Dockerfile
├── docker-compose.yml
├── pom.xml
├── .env
├── .dockerignore
├── .gitignore
├── INSTALLATION.md
├── README.md
│
├── database/
│   └── init/
│       └── db_backup.sql
│
├── nginx/
│   └── default.conf
│
├── secrets/
│   ├── mysql_root_password.txt
│   └── rabbitmq_password.txt
│
└── src/
```

The actual directory structure should match your project.

## 3. Harbor Private Container Registry

Harbor was deployed as the private container registry.
[Docker Harbor Installation Guide](../../../Docker-Harbor/README.md)

### 3.1 Registry configuration

| Setting | Value |
|---|---|
| Registry hostname | `harbor.lab.local` |
| Harbor version | `2.15.5` |
| HTTPS port | `443` |
| Project | `devops-senior` |

### 3.2 Configure registry DNS

Ensure that the Docker host can resolve:

```text
harbor.lab.local
```

Test:

```bash
getent hosts harbor.lab.local
```

### 3.3 Configure TLS certificates

The Harbor TLS certificate and private key were configured using:

```text
/etc/harbor/certs/harbor.lab.local.crt
/etc/harbor/certs/harbor.lab.local.key
```

The certificate must be trusted by the Docker host.

Validate HTTPS connectivity:

```bash
curl -I https://harbor.lab.local
```

Check certificate validity, SAN entries, certificate chain, and trusted CA installation if verification fails.

### 3.4 Validate Harbor access

Open:

```text
https://harbor.lab.local
```

Log in and verify that the project exists:

```text
devops-senior
```

The authenticated user must have permission to push images.

---

## 4. Configure Environment Variables and Secrets

### 4.1 Environment variables

Create or review the `.env` file.

Example:

```dotenv
MYSQL_IMAGE=mysql:8.0.33
MYSQL_DATABASE=accounts
DB_CONTAINER_NAME=vprodb
```

Add the remaining variables referenced by your actual Compose file, including image names and any configured RabbitMQ credentials.

Validate the rendered configuration:

```bash
docker compose config
```

Resolve undefined variables, secrets, or invalid Compose settings before deployment.

### 4.2 Docker secrets

Create the secrets directory:

```bash
mkdir -p secrets
chmod 700 secrets
```

Create the MySQL root password file:

```bash
printf '%s' 'REPLACE_WITH_ROOT_PASSWORD' \
  > secrets/mysql_root_password.txt
```

Protect the file:

```bash
chmod 600 secrets/mysql_root_password.txt
```

If your Compose file declares an application database password secret, create that separately.

The MySQL root secret is mounted inside the container at:

```text
/run/secrets/mysql_root_password
```

Never commit actual secret files to GitHub.

---

## 5. Configure MySQL Database

The final database image:

```text
mysql:8.0.33
```

Database configuration:

| Setting | Value |
|---|---|
| Service name | `db01` |
| Container hostname | `vprodb` |
| Database | `accounts` |
| Internal port | `3306` |
| Persistent directory | `/var/lib/mysql` |

### 5.1 Configure database persistence

The MySQL service uses a named Docker volume:

```yaml
volumes:
  - mysql_data:/var/lib/mysql
  - ./database/init/db_backup.sql:/docker-entrypoint-initdb.d/db_backup.sql:ro
```

The SQL dump is mounted into the MySQL initialization directory.

During the first initialization of an empty data directory, the MySQL entrypoint:

1. Initializes the database.
2. Creates the `accounts` database.
3. Executes `db_backup.sql`.
4. Starts MySQL normally.

**Important:** Initialization scripts run only when the MySQL data directory is empty. Recreating a container with an existing initialized volume does not automatically execute the SQL dump again.

### 5.2 Configure the MySQL health check

The original health check used `healthcheck.sh`, which was unavailable in the selected image.

The replacement uses `mysqladmin ping`:

```yaml
healthcheck:
  test:
    - CMD-SHELL
    - 'mysqladmin ping -h 127.0.0.1 -uroot -p"$$(cat /run/secrets/mysql_root_password)" --silent'
  interval: 10s
  timeout: 5s
  retries: 10
  start_period: 40s
```

### 5.3 Start MySQL

```bash
docker compose up -d db01
```

Check status:

```bash
docker compose ps db01
```

Check logs:

```bash
docker compose logs db01
```

Expected status:

```text
vprodb   Up (healthy)
```

### 5.4 Validate MySQL

```bash
docker compose exec db01 mysql -uroot -p
```

Enter the configured root password.

Execute:

```sql
SELECT VERSION();

SHOW DATABASES;

USE accounts;

SHOW TABLES;
```

This validates database initialization, authentication, and imported tables.

---

## 6. Configure RabbitMQ Message Broker

RabbitMQ provides asynchronous messaging between application components.

In this project, the VProfile application connects to RabbitMQ through the internal Docker network.

### 6.1 RabbitMQ service configuration

| Setting | Value |
|---|---|
| Compose service | `rmq01` |
| Container name | `vprofile-rabbitmq` |
| AMQP port | `5672` |
| Management UI port | `15672` (if enabled) |
| Docker network | `vprofile-network` |

The RabbitMQ service should use a persistent volume so broker data can survive container recreation.

Example Compose configuration:

```yaml
rmq01:
    image: rabbitmq:3.13-management
    container_name: vprofile-rabbitmq

    hostname: rmq01

    restart: unless-stopped

    environment:
      RABBITMQ_DEFAULT_USER: test
      RABBITMQ_DEFAULT_PASS: ${RABBITMQ_DEFAULT_PASS:?Set RABBITMQ_DEFAULT_PASS in .env}
      RABBITMQ_DEFAULT_VHOST: /

    secrets:
      - rabbitmq_password

    volumes:
      - rabbitmq_data:/var/lib/rabbitmq

    networks:
      - vprofile-network

    healthcheck:
      test: ["CMD", "rabbitmq-diagnostics", "-q", "ping"]
      interval: 15s
      timeout: 10s
      retries: 5
      start_period: 40s

    security_opt:
      - no-new-privileges:true
```

Use the image version and environment variable names from your actual Compose configuration. Store credentials outside the public repository.

### 6.2 RabbitMQ connectivity

The application uses the internal Docker hostname:

```text
rmq01:5672
```

The application must use the RabbitMQ credentials configured in the Compose environment.

The AMQP connection should not require publishing port `5672` to the host when the application and RabbitMQ share the same Docker network.

### 6.3 Start RabbitMQ

```bash
docker compose up -d rmq01
```

Check container status:

```bash
docker compose ps rmq01
```

Check logs:

```bash
docker compose logs --tail=100 rmq01
```

### 6.4 Validate RabbitMQ

Run the RabbitMQ diagnostic command:

```bash
docker compose exec rmq01 rabbitmq-diagnostics ping
```

Expected result:

```text
Ping succeeded
```

Check the broker:

```bash
docker compose exec rmq01 rabbitmqctl status
```

If the management plugin is enabled and its port is published, the management interface can be accessed through the configured host address and port.

**Note:** Do not expose the management interface publicly without appropriate authentication and network restrictions.

---

## 7. Configure Memcached

Memcached is an in-memory caching service used by the VProfile application.

It reduces repeated database operations by storing frequently accessed application data in memory.

### 7.1 Memcached service configuration

| Setting | Value |
|---|---|
| Compose service | `mc01` |
| Container name | `vprofile-memcached` |
| Internal port | `11211` |
| Docker network | `vprofile-network` |

Example Compose configuration:

```yaml
mc01:
    image: memcached:1.6-alpine
    container_name: vprofile-memcached

    restart: unless-stopped

    command:
      - -m
      - "128"
      - -c
      - "1024"
      - -t
      - "4"
      - -l
      - 0.0.0.0

    networks:
      - vprofile-network

    healthcheck:
      test:
        - CMD-SHELL
        - "printf 'version\r\n' | nc 127.0.0.1 11211 | grep -q VERSION"
      interval: 15s
      timeout: 5s
      retries: 5
      start_period: 10s

    security_opt:
      - no-new-privileges:true
```

The example allocates 64 MB of memory to Memcached. Adjust the memory limit according to the available resources and your lab configuration.

### 7.2 Memcached connectivity

The application uses the internal Docker hostname:

```text
mc01:11211
```

There is no need to publish port `11211` to the host for communication between containers.

### 7.3 Start Memcached

```bash
docker compose up -d mc01
```

Check status:

```bash
docker compose ps mc01
```

Check logs:

```bash
docker compose logs --tail=100 mc01
```

### 7.4 Validate Memcached

If `nc` is available inside the Memcached container, execute:

```bash
docker compose exec mc01 sh -c \
'printf "version\r\n" | nc 127.0.0.1 11211'
```

Expected response:

```text
VERSION <memcached-version>
```

If `nc` is not installed, use another available Memcached client or test the service from the application container.

---

## 8. Configure Application JDBC and Middleware Connectivity

The application connects to MySQL, RabbitMQ, and Memcached through Docker's internal network.

### 8.1 MySQL JDBC configuration

The final JDBC configuration used in the project:

> [!WARNING]
> Make sure the below properties in the file  /src/> main/resources/application properties before making the artifact (.WAR) using the Dockerfile

```properties
jdbc.driverClassName=com.mysql.cj.jdbc.Driver
jdbc.url=jdbc:mysql://vprodb:3306/accounts?useUnicode=true&characterEncoding=UTF-8&zeroDateTimeBehavior=convertToNull
jdbc.username=root
jdbc.password=REPLACE_WITH_ROOT_PASSWORD
```


The application WAR must include MySQL Connector/J.

The driver JAR used in this lab:

```text
mysql-connector-j-8.0.32.jar
```

Verify the driver inside the deployed application:

```bash
docker compose exec app01 sh -c \
'find /usr/local/tomcat/webapps/ROOT/WEB-INF/lib \
-name "mysql-connector*.jar"'
```

### 8.2 RabbitMQ application configuration

The VProfile application must use the RabbitMQ hostname, AMQP port, and credentials configured in Docker Compose.

The internal endpoint is:

```text
rmq01:5672
```

Check the application's actual properties or Spring configuration for its RabbitMQ connection settings.

### 8.3 Memcached application configuration

The application must use:

```text
mc01:11211
```

Check the application's actual configuration for its Memcached host and port settings.

**Important:** The exact RabbitMQ and Memcached property names depend on the VProfile application version and its configuration files. Preserve the existing application settings unless a deliberate configuration change is required.

---

## 9. Build the Application Artifact and Docker Image

The project uses a multi-stage Dockerfile.

The build stage uses Maven to package the application, and the runtime stage uses Tomcat.

The WAR artifact is generated as:

```text
target/vprofile-v2.war
```

The runtime image deploys it as:

```text
/usr/local/tomcat/webapps/ROOT.war
```

### 9.1 Build the Docker image

The build command used:

```bash
docker build -t vapp:v4 .
```

This builds the application image locally.

If Docker cannot retrieve base image metadata and reports:

```text
error getting credentials - err: exit status 1
```

Check Docker Hub authentication and credential-helper configuration.

Test pulling the base image directly:

```bash
docker pull tomcat:9-jre11
```

Resolve registry authentication issues before rebuilding.

### 9.2 Verify the local image

```bash
docker images
```

Confirm that:

```text
vapp:v4
```

exists.

---

## 10. Publish the Application Image to Harbor

Tag the local image:

```bash
docker tag vapp:v4 \
harbor.lab.local/devops-senior/vapp:v4
```

Log in:

```bash
docker login harbor.lab.local
```

Push:

```bash
docker push \
harbor.lab.local/devops-senior/vapp:v4
```

Verify the repository and image tag through the Harbor web interface.

---

## 11. Configure Nginx Reverse Proxy

Nginx acts as the external HTTP entry point for the application.

It forwards incoming requests to the Tomcat application over the internal Docker network.

### 11.1 Nginx service configuration

| Setting | Value |
|---|---|
| Compose service | `web01` |
| Container name | `vprofile-nginx` |
| Host port | `80` |
| Container port | `80` |
| Upstream application | `app01:8080` |

Example Compose configuration:

```yaml
web01:
    image: nginx:1.28-alpine
    container_name: vprofile-nginx

    restart: unless-stopped

    ports:
      - "80:80"

    volumes:
      - ./nginx/default.conf:/etc/nginx/conf.d/default.conf:ro

    depends_on:
      app01:
        condition: service_started

    networks:
      - vprofile-network

    healthcheck:
      test: ["CMD", "nginx", "-t"]
      interval: 30s
      timeout: 5s
      retries: 3

    security_opt:
      - no-new-privileges:true
```

The exact image tag and volume paths should match your project configuration.

### 11.2 Configure Nginx reverse proxy

Create or review:

```text
nginx/default.conf
```

Example configuration:
```nginx
upstream vproapp {
    server app01:8080;
    keepalive 32;
}

server {
    listen 80;
    server_name _;
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log warn;

    location / {

        proxy_pass http://vproapp;

        proxy_http_version 1.1;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_connect_timeout 10s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
```

Explanation:

| Directive | Purpose |
|---|---|
| `listen 80` | Accepts HTTP traffic |
| `server_name _` | Default server name |
| `proxy_pass` | Forwards requests to Tomcat |
| `Host` | Preserves the original HTTP host |
| `X-Real-IP` | Passes the client IP |
| `X-Forwarded-For` | Preserves proxy forwarding information |
| `X-Forwarded-Proto` | Indicates the original protocol |

The upstream hostname `app01` is the Compose service name and must be reachable through the shared Docker network.

### 11.3 Start Nginx

```bash
docker compose up -d web01
```

Check status:

```bash
docker compose ps web01
```

Validate the Nginx configuration:

```bash
docker compose exec web01 nginx -t
```

Expected:

```text
syntax is ok
test is successful
```

Check logs:

```bash
docker compose logs --tail=100 web01
```

### 11.4 Validate reverse proxy

From the Docker host:

```bash
curl -I http://localhost/
```

The request should reach the VProfile application through Nginx.

A successful Nginx startup alone does not prove that the Java application has deployed correctly. Check Tomcat logs and the HTTP response as well.

---

## 12. Deploy the Complete Application

After configuring the database, RabbitMQ, Memcached, application, and Nginx, validate the Compose file:

```bash
docker compose config
```

Start all services:

```bash
docker compose up -d
```

Check the service status:

```bash
docker compose ps
```

Review the logs:

```bash
docker compose logs --tail=100
```

For individual services:

```bash
docker compose logs db01
docker compose logs rmq01
docker compose logs mc01
docker compose logs app01
docker compose logs web01
```

Check that:

- MySQL is healthy.
- RabbitMQ is healthy.
- Memcached is running.
- Tomcat successfully deploys the application.
- Nginx successfully proxies requests to Tomcat.

---

## 13. Validation and Testing

### 13.1 Validate all containers

```bash
docker compose ps
```

### 13.2 Validate the Docker network

```bash
docker network ls
```

Inspect the network:

```bash
docker network inspect vprofile-project_vprofile-network
```

The actual network name depends on the Compose project name.

### 13.3 Validate MySQL

```bash
docker compose exec db01 \
mysql -uroot -p accounts \
-e "SELECT VERSION(), DATABASE();"
```

### 13.4 Validate RabbitMQ

```bash
docker compose exec rmq01 rabbitmq-diagnostics ping
```

### 13.5 Validate Memcached

```bash
docker compose exec mc01 sh -c \
'printf "version\r\n" | nc 127.0.0.1 11211'
```

### 13.6 Validate application-to-database DNS

```bash
docker compose exec app01 getent hosts vprodb
```

### 13.7 Validate application-to-RabbitMQ DNS

```bash
docker compose exec app01 getent hosts rmq01
```

### 13.8 Validate application-to-Memcached DNS

```bash
docker compose exec app01 getent hosts mc01
```

### 13.9 Validate Nginx configuration

```bash
docker compose exec web01 nginx -t
```

### 13.10 Test the application

```bash
curl -I http://localhost/
```

If the application returns HTTP 404 or an error, investigate the application deployment and logs:

```bash
docker compose logs --tail=200 app01
```

Look for:

- JDBC connection failures.
- Database authentication errors.
- Hibernate initialization exceptions.
- RabbitMQ connection failures.
- Memcached connectivity problems.
- Spring application initialization errors.

---

## 14. Updating the Application Without Deleting Persistent Data

When application code or `application.properties` changes, rebuild the WAR and Docker image.

With the multi-stage Dockerfile, Docker performs the Maven build automatically.

Build a new version:

```bash
docker build -t vapp:v5 .
```

Tag it:

```bash
docker tag vapp:v5 \
harbor.lab.local/devops-senior/vprofile-app:v5
```

Push it:

```bash
docker push \
harbor.lab.local/devops-senior/vprofile-app:v5
```

Update the image reference in Compose:

```yaml
app01:
  image: harbor.lab.local/devops-senior/vprofile-app:v5
```

Pull and deploy:

```bash
docker compose pull app01
docker compose up -d --no-deps app01
```

Check logs:

```bash
docker compose logs --tail=100 app01
```

**Important:** Application image updates do not require deleting the MySQL or RabbitMQ volumes.

---

## 15. Troubleshooting Notes

### Issue 1: MySQL reports unhealthy

Symptom:

```text
container vprodb is unhealthy
```

Cause encountered:

```text
healthcheck.sh: executable file not found in $PATH
```

Resolution: Replace the unavailable health-check command with `mysqladmin ping` using the mounted root password secret.

### Issue 2: MySQL rejects MYSQL_USER=root

Symptom:

```text
MYSQL_USER="root" cannot be used for the root user
```

Resolution: Use `MYSQL_ROOT_PASSWORD_FILE` to configure the root account. Do not set `MYSQL_USER=root`.

### Issue 3: Application cannot resolve MySQL hostname

Check:

```bash
docker compose exec app01 getent hosts vprodb
```

Ensure the application and database share the same Docker network.

### Issue 4: RabbitMQ connection failure

Check broker status:

```bash
docker compose exec rmq01 rabbitmq-diagnostics ping
```

Check the application hostname and port:

```text
rmq01:5672
```

Verify that the application credentials match the configured RabbitMQ account.

### Issue 5: Memcached connection failure

Check the container:

```bash
docker compose ps mc01
```

Check service connectivity on:

```text
mc01:11211
```

Verify that the application and Memcached share the same network.

### Issue 6: Nginx returns 502 Bad Gateway

A 502 usually indicates that Nginx cannot successfully reach the upstream application.

Check:

```bash
docker compose logs web01
docker compose logs app01
```

Validate the Nginx configuration:

```bash
docker compose exec web01 nginx -t
```

Ensure the upstream is:

```text
app01:8080
```

and that Tomcat is running and the application is deployed.

### Issue 7: Docker build fails retrieving image metadata

Symptom:

```text
error getting credentials - err: exit status 1
```

Check Docker Hub authentication and credential-helper configuration.

Test:

```bash
docker pull tomcat:9-jre11
```

### Issue 8: Tomcat starts but the application returns HTTP 404

Check:

```bash
docker compose logs --tail=200 app01
```

Investigate WAR deployment, JDBC configuration, database connectivity, and Spring/Hibernate initialization.

### Issue 9: SQL initialization does not execute again

MySQL initialization scripts run only when the data directory is initially empty.

For existing databases, apply database changes through an intentional migration or SQL execution process.

Do not delete the existing database volume simply to rerun the application build.

---

## 16. Persistent Storage and Cleanup

List Docker volumes:

```bash
docker volume ls
```

The MySQL and RabbitMQ named volumes should be retained when their persistent data is required.

Normal shutdown:

```bash
docker compose down
```

This removes containers and the Compose network but preserves named volumes.

Avoid:

```bash
docker compose down -v
```

unless you deliberately intend to remove Compose-managed volumes and their data.

Application image cleanup should be performed separately after confirming that the new image works and an older rollback version is no longer required.

---

## 17. Final Deployment Workflow

```text
Application Source Code
          |
          v
      Maven Build
          |
          v
       WAR File
          |
          v
      Docker Build
          |
          v
    Versioned Image
          |
          v
    Harbor Registry
          |
          v
     Docker Compose
          |
          +------------------+
          |                  |
          v                  v
      MySQL DB          RabbitMQ
          |                  |
          |                  |
          +--------+---------+
                   |
                   v
               Memcached
                   |
                   v
              Tomcat App
                   |
                   v
                Nginx
                   |
                   v
               End User
```

## 18. Security and Operational Recommendations

- Never commit real passwords or private TLS keys.
- Keep `.env` and `secrets/` out of public Git repositories.
- Maintain `.env.example` with placeholder values.
- Use versioned application image tags.
- Keep database and RabbitMQ volumes persistent.
- Use a dedicated database account rather than root in production.
- Back up MySQL data before destructive operations.
- Restrict access to the RabbitMQ management interface.
- Do not expose Memcached directly to untrusted networks.
- Use HTTPS for production web traffic.
- Ensure Harbor certificates are trusted by all Docker hosts.

---

**Project:** VProfile Containerized Multi-Tier Application

**Orchestration:** Docker Compose

**Private Registry:** Harbor 2.15.5

**Database:** MySQL 8.0.33

**Application Runtime:** Apache Tomcat 9 / Java 11

**Reverse Proxy:** Nginx

**Message Broker:** RabbitMQ

**Caching:** Memcached
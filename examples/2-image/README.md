# Docker Images

## Simple Image

Write a script named `run.sh` that can be executed without any dependencies.

```bash
#!/bin/sh
while :
do
   echo "[$(date)] Infinite loop [ hit CTRL+C to stop]"
   sleep 1
done
```

Don't forget to make `run.sh` executable:
```console
chmod +x run.sh
```

Let's Dockerize this.

```Dockerfile
FROM alpine:3.12.1

COPY run.sh run.sh

CMD ["./run.sh"]
```

```console
docker build -t simple/simple:1.0 .
docker run --detach --name simple simple/simple:1.0
docker logs -f simple
```

## Multi Stage Build

Go back to `1-maven` example directory and write multi-stage Dockerfile.

Existing Dockerfile:

```Dockerfile
FROM maven:3.6.3-openjdk-16-slim

COPY . /usr/src/app
WORKDIR /usr/src/app
RUN mvn package

CMD ["java", "-jar", "target/app.war"]
```

```console
docker build --tag java-example:1.0 -f ../1-maven/java-example/Dockerfile.final ../1-maven/java-example
```

We don't need Maven once the build is completed:

```Dockerfile
FROM maven:3.6.3-openjdk-16-slim as BUILD

COPY . /usr/src/app
WORKDIR /usr/src/app
RUN mvn package

# Once we use FROM, it means we are at a different stage. 

FROM openjdk:16-jdk-alpine3.12
COPY --from=BUILD /usr/src/app/target/app.war .
CMD ["java", "-jar", "app.war"]
```

```console
docker build --tag java-multistage:1.0 -f Dockerfile.multistage ../1-maven/java-example
docker images
docker run --publish 2000:8080 --detach --name jv-multi java-multistage:1.0
docker rm --force jv-multi
```
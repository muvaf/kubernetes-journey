# Docker Bridge Network

Docker can create software defined networks for you in your computer. It essentially creates virtual network devices and emulate networks between them.

## Default Bridge

When we run something with `docker run`, it starts in the default bridge network.

```console
docker run --publish 8000:8080 --detach --name bb bulletinboard:1.0
docker run --publish 8000:8080 --detach --name jv java-example:1.0
```

> You should see an error about ports conflicting since they are on the same network, trying to use the same port.

```console
docker rm --force jv
docker run --publish 2000:8080 --detach --name jv java-example:1.0
```

Let's see how the network looks like:
```console
docker network ls
docker network inspect bridge
```

TODO: inspect template command not working in windows

Let's get assigned IP of each container in that network:
```console
docker inspect bb
```
```console
docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' bb
```
```console
docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' jv
```

Test if they can see each other:
```
docker exec -it bb bash
apt update && apt install iputils-ping -y
ping # add IP you got from the inspect query of container jv
```

Cleanup:
```console
docker rm --force jv bb
```

## User-defined Bridge Network

```console
docker network create -d bridge mybridge
docker network ls
docker network inspect mybridge
```

Let's add containers to our bridge!
```console
docker run --publish 8000:8080 --detach --net=mybridge --name bb bulletinboard:1.0
docker run --publish 2000:8080 --detach --net=mybridge --name jv java-example:1.0
```

Another one in the default network:
```console
docker run --publish 3000:8080 --detach --name jv-default java-example:1.0
```

```console
docker network inspect mybridge
```

Let's get IP of `jv`:
```console
docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' jv
```

Test the connectivity:

```console
docker exec -it bb bash
apt update && apt install iputils-ping -y
ping # add IP you got from the inspect query of container jv
ping jv
ping jv-default
```

Now open a new tab and let's connect `jv-default` to this network:
```console
docker network connect mybridge jv-default
```

Go back to the container `jv` and try again:
```console
ping jv-default
```

Cleanup:
```console
docker rm --force jv jv-default bb
```

## Host Network

Just like any process. Outsiders can access it through your machine's external IP address.

```console
docker run --publish 80:8080 --detach --net=host --name jv java-example:1.0
WARNING: Published ports are discarded when using host network mode
a7ee01eca5af2a6d8e06c0f90c49e294619b69d5780ae3616683928fb7224cb8
```

```console
docker rm --force jv
```
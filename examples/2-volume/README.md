# Docker Volumes

## Bind-mount Driver

Not recommended.

```console
mkdir /tmp/binddir
echo "aa" > /tmp/binddir/file1
```

Mount the directory to the container:
```console
docker run --publish 8000:8080 --detach --mount type=bind,source=/tmp/binddir,target=/tmp/incontainer --name jv java-example:1.0
```

```console
docker exec -it jv bash
ls -al /tmp/incontainer
```

Cleanup:
```console
docker rm --force jv
```

## Volumes

```console
docker run --publish 8000:8080 --detach --volume myvolume:/tmp/newdir --name jv-vol java-example:1.0
```
```console
docker exec -it jv-vol bash
ls -al /tmp/newdir
echo "incontainer file" > /tmp/newdir/file1
```

Now let's see the volume in the host:
```console
docker volume ls
docker volume inspect myvolume
docker rm --force jv-vol
```

Wire it to another container:
```console
docker run --publish 8000:8080 --detach --volume myvolume:/tmp/filesfromoldvol --name bb bulletinboard:1.0
docker exec -it bb bash
ls /tmp/filesfromoldvol
cat /tmp/filesfromoldvol/file1
```

Use it in another container at the same time:
```console
docker run --publish 2000:8080 --detach --volume myvolume:/tmp/second --name bb-reuse bulletinboard:1.0
docker exec -it bb-reuse bash
ls /tmp/second
cat /tmp/second/file1
```

Cleanup:
```console
docker rm --force bb bb-reuse
docker volume prune
```
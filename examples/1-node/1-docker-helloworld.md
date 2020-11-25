# Docker Hello World!

## Install Docker

Mac and Windows: https://www.docker.com/products/docker-desktop

Ubuntu:
```console
sudo apt-get update && sudo apt-get install \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common
```
```console
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
```

x86_64/amd64

```console
sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"
```
```console
sudo apt-get update && sudo apt-get install docker-ce docker-ce-cli containerd.io
```

## First Run

Let's see if Docker has been installed correctly.

```console
sudo docker run hello-world
```

If an error comes up requiring sudo, add `alias docker="sudo docker"` to `~/.bash_rc`

## Run Example Bulletin Board

```console
cd examples/1-node
```

Run the app:
```console
npm install
npm start
```

```console
docker build --tag bulletinboard:1.0 .
```

Now the image is ready!
```console
docker run --publish 8000:8080 --detach --name bb bulletinboard:1.0
```

Go visit localhost:8000 !

### Cleanup

```console
docker rm --force bb
```
# Bulletin Board Example

## Install Requirements

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

Install NPM: https://nodejs.org/en/download/

Install Kind cluster: https://kind.sigs.k8s.io/docs/user/quick-start/

Install Kubectl client: https://kubernetes.io/docs/tasks/tools/install-kubectl/

## First Run

Let's see if Docker has been installed correctly.

```console
sudo docker run hello-world
```

If an error comes up requiring sudo, add `alias docker="sudo docker"` to `~/.bash_rc`

## Run Bulletin Board Directly

```console
cd examples/1-node
```

Run the app:
```console
npm install
npm start
```

## Dockerize Bulletin Board

Write the Dockerfile:
```Dockerfile
FROM node:current-slim

WORKDIR /usr/src/app

COPY . .

RUN npm install

EXPOSE 8080

CMD [ "npm", "start" ]
```

```console
docker build --tag bulletinboard:1.0 .
```

Now the image is ready!
```console
# Inside port 8080 is published as 8000
docker run --publish 8000:8080 --detach --name bb bulletinboard:1.0
```

Go visit localhost:8000 !

## Run On Kubernetes

We create a new cluster:
```console
kind create cluster
```

We will load our image into the cluster:
```console
kind load docker-image bulletinboard:1.0
```

Now we will run it in a `Pod`:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: bulletin
spec:
  containers:
    - name: bulletin
      image: bulletinboard:1.0
      ports:
        - name: web
          containerPort: 8080
          protocol: TCP
```

Port-forward to access:
```console
kubectl port-forward bulletin 8000:8080
```

Go visit localhost:8000 !

### Cleanup

```console
docker rm --force bb
kind delete clusters kind
```
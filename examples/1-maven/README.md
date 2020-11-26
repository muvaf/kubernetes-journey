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

Install Maven:
 * Mac: `brew install maven`
 * Ubuntu: `sudo apt-get install maven`
 * Windows:  https://maven.apache.org/guides/getting-started/windows-prerequisites.html

Install Kind cluster: https://kind.sigs.k8s.io/docs/user/quick-start/

Install Kubectl client: https://kubernetes.io/docs/tasks/tools/install-kubectl/

## First Run

Let's see if Docker has been installed correctly.

```console
sudo docker run hello-world
```

If an error comes up requiring sudo, add `alias docker="sudo docker"` to `~/.bash_rc`

## Run Example Directly

```console
cd java-example
```

Run the app:
```console
mvn package
java -jar target/app.war
```

Go visit http://localhost:8080/hello !

## Dockerize

Write the Dockerfile:
```Dockerfile
FROM maven:3.6.3-openjdk-16-slim

COPY . /usr/src/app

WORKDIR /usr/src/app

RUN mvn package

CMD ["java", "-jar", "target/app.war"]
```

```console
docker build --tag java-example:1.0 .
```

Now the image is ready!
```console
# Inside port 8080 is published as 8000
docker run --publish 8000:8080 --detach --name example-container java-example:1.0
```

Go visit http://localhost:8000/hello !

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
  name: example-pod
spec:
  containers:
    - name: example
      image: java-example:1.0
      ports:
        - name: web
          containerPort: 8080
          protocol: TCP
```

Port-forward to access:
```console
kubectl port-forward bulletin 8000:8080
```

Go visit localhost:8000/hello !

### Cleanup

```console
docker rm --force example-container
kind delete clusters kind
```
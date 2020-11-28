# Kubernetes Pod

Make sure Kubernetes cluster is up.

```console
kubectl get pods
kubectl version
```

You can create dev cluster either:
* Using `kind create cluster`
* Using Docker Desktop cluster.

## Simple Pod

First, let's build the image we will use:
```console
docker build -t bulletinboard:1.0 -f ../1-node/node-bulletin-board/Dockerfile.final ../1-node/node-bulletin-board
```

We will create a simple `Pod`. Create a file named `pod.yaml`:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: example-pod
spec:
  containers:
    - name: example
      image: bulletinboard:1.0
      ports:
        - name: web
          containerPort: 8080
          protocol: TCP
```

Now run:
```console
kubectl apply -f pod.yaml
```

Set up a tunnel:
```console
kubectl port-forward example-pod 8000:8080
```

Go visit localhost:8000

## Multiple Containers

We will create a Pod to represent the Compose Python+Redis example from Compose examples.

Original `docker-compose.yaml`:
```yaml
version: "3.8"
services:
  web:
    build: .
    ports:
      - "5000:5000"
  redis:
    image: "redis:alpine"
```

Since `kubectl` does not build anything, we need to build the `web`
 image first:
```console
docker build -t web:1.0 -f ../3-compose/python-redis/Dockerfile.final ../3-compose/python-redis
```

Load to cluster:
```console
 kind load docker-image web:1.0
```

As Kubernetes `Pod`:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-redis
spec:
  containers:
    - name: web
      image: web:1.0
      env:
      - name: REDIS_URL
        value: "localhost"
      ports:
        - name: web
          containerPort: 5000
          protocol: TCP
    - name: redis
      image: redis:alpine
```

Create a `multicontainer.yaml` with that content. Run:
```console
kubectl apply -f multicontainer.yaml
```

## Pod With Volume

We can use volume
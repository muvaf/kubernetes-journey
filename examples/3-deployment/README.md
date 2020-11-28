# Deployment

## Simple

Create a `simple.yaml` file with the following content:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: bulletin-deployment
spec:
  replicas: 3
  selector:
    matchLabels:
      app: bulletin
  template:
    metadata:
      labels:
        app: bulletin
    spec:
      containers:
        - name: example
          image: bulletinboard:1.0
          ports:
            - name: web
              containerPort: 8080
              protocol: TCP
```

Run:
```console
kubectl apply -f simple.yaml
kubectl get pods
```

Now let's set up a tunnel:
```console
kubectl port-forward <pod name> 8000:8080
```

Visit localhost:8000

## Scale Up

Now let's create another file called `more-replicas.yaml`:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: bulletin-deployment
spec:
  replicas: 6
  selector:
    matchLabels:
      app: bulletin
  template:
    metadata:
      labels:
        app: bulletin
    spec:
      containers:
        - name: example
          image: bulletinboard:1.0
          ports:
            - name: web
              containerPort: 8080
              protocol: TCP
```

You can see the name is same. We are patching the existing with new replica number 6.

## Update The Image

Now we will do an imperative operation to change the image to a new version. First we need to deploy the redis example:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis-deployment
spec:
  replicas: 3
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
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

Run:
```yaml
kubectl apply -f redis-deployment.yaml
```

Now let's build a new version. Go change `app.py` and rebuild:
```console
docker build -t web:2.0 -f ../3-compose/python-redis/Dockerfile.final ../3-compose/python-redis
```

Look at the status of existing deployment:
```console
kubectl get deployment redis-deployment -o yaml
```

Human-readable:
```console
kubectl describe deployment redis-deployment
```

After it is up, run:
```console
kubectl edit deployment redis-deployment
```

And change the image to `web:2.0`, watch the update rolling out.

## Roll Back!

Check rollout history:
```console
kubectl rollout history deployment/redis-deployment
```

Let's get back to the earlier version:
```console
kubectl rollout undo deployment/redis-deployment
```

## Let's do Wordpress

Deploy Wordpress with 1 `Deployment` for Wordpress and 1 `Deployment` for MySQL with no volumes.

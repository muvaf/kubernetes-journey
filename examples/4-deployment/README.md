# Deployment

Create your kind cluster with the following command:
```
kind create cluster --config=kind-config.yaml
```

Load the following images into your cluster:
```
docker pull mysql:5.7
kind load docker-image mysql:5.7
docker pull wordpress:5.5.3
kind load docker-image wordpress:5.5.3
kind load docker-image bulletinboard:1.0
```

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

Now let's create another file called `scaled-up.yaml`:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: bulletin-deployment
spec:
  replicas: 20
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

Run the following:
```yaml
kubectl apply -f scaled-up.yaml
```

You can see the names are same. We are patching the existing with new replica number 20.

## Update The Image

Now we will do an imperative operation to change the image to a new version. First we need to deploy the redis example:

Create a file called `multi-container.yaml` with the following content:

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
kubectl apply -f multi-container.yaml
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

## Wordpress

Let's do Wordpress example using only `Deployment`.

Create `mysql.yaml`:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mysql
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mysql
  template:
    metadata:
      labels:
        app: mysql
    spec:
      containers:
        - name: server
          image: mysql:5.7
          env:
          - name: MYSQL_ROOT_PASSWORD
            value: "somewordpress"
          - name: MYSQL_DATABASE
            value: "somewordpress"
          - name: MYSQL_USER
            value: "somewordpress"
          - name: MYSQL_PASSWORD
            value: "somewordpress"
          ports:
            - name: mysql
              containerPort: 3306
              protocol: TCP
```

Run `kubectl apply -f mysql.yaml`

Now take the Pod IP of MySQL:
```
kubectl describe pod <mysql pod name here>
```

Now put it in `wp.yaml`:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: wp
spec:
  replicas: 1
  selector:
    matchLabels:
      app: wp
  template:
    metadata:
      labels:
        app: wp
    spec:
      containers:
        - name: wordpress
          image: wordpress:5.5.3
          env:
          - name: WORDPRESS_DB_HOST
            value: "<MySQL Pod IP Here>:3306" # like 10.2.0.1:3306
          - name: WORDPRESS_DB_NAME
            value: "somewordpress"
          - name: WORDPRESS_DB_USER
            value: "somewordpress"
          - name: WORDPRESS_DB_PASSWORD
            value: "somewordpress"
          ports:
            - name: wp
              containerPort: 80
              protocol: TCP
```

Run `kubectl apply -f wp.yaml`

Let's see if the DB connection is established. Open a tunnel to Wordpress:
```
kubectl port-forward <wp pod name> 8080:80
```

Visit `localhost:8080` !

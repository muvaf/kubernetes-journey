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

# Service

## In-cluster Communication

So far, we accessed pods by openning a tunnel to them. We can expose them to outside the cluster.

Let's do it with Wordpress example we had earlier with Docker Compose.

Create a file called `mysql.yaml`

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

```
kubectl apply -f mysql.yaml
```

Get the `Pod` status to see the IP of the Pod:
```
kubectl describe pod <pod name here>
```

Now take a note of the `podIP` in status and put it into Wordpress Deployment.

Create a file called `wp.yaml`:
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
            value: <change this value!> # like 10.2.0.1:3306
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

Run:
```
kubectl apply -f wp.yaml
```

Now let's check if Wordpress is able to connect to MySQL by openning a tunnel from our local machine:
```
kubectl port-forward <wordpress pod name here> 8080:80
```

Visit `localhost:8080` now.

Now kill the MySQL pod:
```
kubectl delete pod <mysql pod name here>
```

You will see that another one will be started immediately. However, Wordpress is not accessible anymore because IP has changed.

Just like in Docker, we can actually call other pods by a string name!

Let's create a `Service` to access MySQL.


Create a file called `mysql-service.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: mysql
spec:
  type: ClusterIP
  selector:
    app: mysql
  ports:
    - port: 3306
```

```
kubectl apply -f mysql-service.yaml
```

We can access MySQL by using `mysql` as its URL now. Let's change Wordpress `Deployment`:

```
kubectl edit deployment wp
# Now change the URL to "mysql:3306"
```

We can again open a tunnel to see if database connection works:
```
kubectl port-forward <wp pod name here> 8080:80
```

While it's open, let's go ahead and kill MySQL pod so that it gets a new IP. Then we'll check if Wordpress still works.

```
kubectl delete pod <mysql pod name here>
```

## External Communication

So far we opened tunnels to pods to access. Now we'll see how we can expose them to outside of the cluster just like any other service that can be accessed through browser.

### NodePort

We can expose specific port on all the machines that run the Wordpress `Pod`.

Create a file called `wp-service.yaml`:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: wp
spec:
  type: NodePort
  selector:
    app: wp
  ports:
    - port: 80
      nodePort: 30067
```

Run:
```
kubectl apply -f wp-service.yaml
```

Now we can access Wordpress through `127.0.0.1:30067` !

### LoadBalancer

In cloud providers, we get a `LoadBalancer` plugin installed already.

For on-prem cluster that we'll create, we can use MetalLB plugin. It needs a public IP address pool to assign during setup and later it will use IP from that pool as public IP for the loadbalancer. Let's do that when we go over cluster administration parts.

### ExternalName

This is where you can access an external service. For example, let's say we have MySQL running somewhere outside the cluster.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: mysql
spec:
  type: ExternalName
  externalName: mydatabase.outsidecluster.com
```

Then in my Wordpress, when I query `mysql:3306` it will be redirected to `mydatabase.outsidecluster.com`
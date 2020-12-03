# Service

## In-cluster Communication

In the earlier Wordpress example, we used IP of MySQL pod. However, we know that static IPs are not recommended because every `Pod` gets a unique IP.

Let's say we roll out an update or Pod crashed and needs to be recreated.

Kill the MySQL pod:
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

### Ingress

`Ingress` is another kind like `Service` that allows us access the cluster from outside but we'll come back to that later.

# Volumes

Container file systems are ephemeral; they are wiped out when pod is restarted or container is crashed. But we can provide persistent volumes just like Docker and Docker Compose.

## EmptyDir for Container Crash

Create a `pod.yaml`:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: simple
spec:
  containers:
  - image: bulletinboard:1.0
    name: bb
```

Now run `kubectl exec -it simple sh`

Then create a file in `/var/lib/mysql`:
```yaml
mkdir -p /var/lib/mysql
touch /var/lib/mysql/afile
```

Now let's crash the container and see if the file is still there:
```
# We are still in the container.
kill 1
```

When you run `kubectl get pods`, you'll see that `RESTARTS` is increased by one. Let's see if our file is still there:
```
kubectl exec -it simple sh
ls /var/lib/mysql/afile
```

Now let's try to create an empty volume to keep data even if the container crashes.

Create a `pod-emptydir.yaml`:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: emptydir-example
spec:
  containers:
  - image: bulletinboard:1.0
    name: bb
    volumeMounts:
    - mountPath: /var/lib/mysql
      name: test-volume
  volumes:
  - name: test-volume
    emptyDir: {}
```

Create our file:
```
kubectl exec -it emptydir-example sh
mkdir -p /var/lib/mysql
touch /var/lib/mysql/afile
```

Kill the container process:
```
kill 1
```

Now let's get into container again and see if the file is there:
```
kubectl exec -it emptydir-example sh
ls /var/lib/mysql/afile
```

It's there! That's how volumes are persisted throughout all crashes in the `Pod`. `emptyDir` is the simplest one to get an empty volume.

## CephFS Provider

Cloud providers have their own storage solutions relying on network. In on-prem, we can use Ceph to provision storage. But we will not go into details of that here.

## HostPath

It's essentially using a path in the `Node`, very similar to bind-mount type in Docker. However, it's usually not recommended because if the `Pod` is moved to another `Node`, the data is lost.

Let's create a `pod-hostpath.yaml`:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: hostpath-example
spec:
  containers:
  - image: alpine:latest
    name: bb
    command:
    - sleep
    - "10000"
    volumeMounts:
    - mountPath: /var/lib/mysql
      name: test-volume
  volumes:
  - name: test-volume
    hostPath:
      path: /tmp/kind-cluster-host-data
      type: DirectoryOrCreate
```

Now get into the container and create a file:
```
kubectl exec -it hostpath-example sh
mkdir -p /var/lib/mysql
echo "some content" > /var/lib/mysql/afile
```

> In MacOS or Windows, we won't see it in our actual machine because Docker runs in a VM.
> However, you can go into that VM by running `docker exec -it kind-control-plane sh` and look at the file.

Go back to the `Node` you are using to see if the file is there:
```
ls /tmp/kind-cluster-host-data
```
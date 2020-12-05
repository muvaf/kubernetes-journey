
```
kind create cluster --config=new-kind-config.yaml
```

```
kubectl apply -f https://docs.projectcalico.org/v3.8/manifests/calico.yaml
kubectl -n kube-system set env daemonset/calico-node FELIX_IGNORELOOSERPF=true
```

# Namespace

Run `kubectl get namespace`.

We can create a namespace with:
```
kubectl create namespace customer-1
```

Then we can make our queries specific to that namespace:
```
kubectl get pods -n customer-1
kubectl get pods -n kube-system
```

Switch default namespace to something other than `default`:
```
kubectl config set-context --current --namespace=customer-1
```

# Pod Quotas

## CPU Limits & Requests

Let's create a `Pod` whose container will try to use 2 CPUs while its limit is 1.

Create `pod-cpu.yaml`:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: cpu-demo
spec:
  containers:
  - name: cpu-demo-ctr
    image: vish/stress
    resources:
      limits:
        cpu: "1"
      requests:
        cpu: "0.5"
    args:
    - -cpus
    - "2"
```

Let's see how much it is currently using:
```
kubectl top pod cpu-demo
```

Let's try to **request** more than available in one node.

Create `pod-cpu-toomuch.yaml`:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: cpu-demo-2
spec:
  containers:
  - name: cpu-demo-ctr-2
    image: vish/stress
    resources:
      limits:
        cpu: "100"
      requests:
        cpu: "100"
    args:
    - -cpus
    - "100"
```

Check if it's scheduled:
```
kubectl get pods
```

## Memory Limits & Requests

### Normal

Let's create a file `pod-memory.yaml`:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: memory-demo
spec:
  containers:
  - name: memory-demo-ctr
    image: polinux/stress
    resources:
      limits:
        memory: "200Mi"
      requests:
        memory: "100Mi"
    command: ["stress"]
    args: ["--vm", "1", "--vm-bytes", "150M", "--vm-hang", "1"]
```

Run `kubectl top pod memory-demo` to see the usage.

### Stressed App

Let's create a file `pod-no-memory.yaml`:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: memory-demo-2
spec:
  containers:
  - name: memory-demo-2-ctr
    image: polinux/stress
    resources:
      requests:
        memory: "50Mi"
      limits:
        memory: "100Mi"
    command: ["stress"]
    args: ["--vm", "1", "--vm-bytes", "250M", "--vm-hang", "1"]
```

We should see some throttling:
```
kubectl top pod memory-demo-2
```

Check the status:
```
kubectl describe pod memory-demo-2
kubectl get pod memory-demo-2 -o yaml
```

### Too Big

Let's create a file `pod-toomuch-memory.yaml`:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: memory-demo-3
spec:
  containers:
  - name: memory-demo-3-ctr
    image: polinux/stress
    resources:
      limits:
        memory: "1000Gi"
      requests:
        memory: "1000Gi"
    command: ["stress"]
    args: ["--vm", "1", "--vm-bytes", "150M", "--vm-hang", "1"]
```

Run `kubectl apply -f pod-toomuch-memory.yaml`

See if it's scheduled:
```
kubectl get pods
```

# Namespace Quotas

## CPU & Memory

### Default Limits and Requests

Let's create a namespace:
```
kubectl create namespace ns-defaulted
```

Create `LimitRange` in a file called `limitrange.yaml`:
```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: mem-limit-range
  namespace: ns-defaulted
spec:
  limits:
  - default:
      memory: 512Mi
    defaultRequest:
      memory: 256Mi
    type: Container
```

Run `kubectl apply -f limitrange.yaml`

Now let's see this in action by creating a simple `Pod`:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: default-mem-demo
  namespace: ns-defaulted
spec:
  containers:
  - name: sleep
    image: spaster/alpine-sleep:latest
```

Let's check if it has any limits and requests:
```
kubectl describe pod default-mem-demo -n ns-defaulted
kubectl get pod default-mem-demo -o yaml
```

Cleanup:
```
kubectl delete ns ns-defaulted
```

### Per-container Max & Min

We can specify max & min of each container can ever get.

Create a namespace:
```
kubectl create namespace ns-max-min
```

Create a `LimitRange` in a file called `limitrange-max.yaml`:
```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: mem-min-max-demo-lr
  namespace: ns-max-min
spec:
  limits:
  - max:
      memory: 1Gi
    min:
      memory: 500Mi
    type: Container
```

Let's create a `Pod` whose container does not respect max.

Create a file called `pod-container-max.yaml`:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: constraints-mem-demo-2
  namespace: ns-max-min
spec:
  containers:
  - name: constraints-mem-demo-2-ctr
    image: nginx
    resources:
      limits:
        memory: "1.5Gi"
      requests:
        memory: "800Mi"
```

Run `kubectl apply -f pod-container-max.yaml`

Cleanup: `kubectl delete ns ns-max-min`


### Per-pod Limits and Requests

Create a namespace:
```
kubectl create ns ns-per-pod
```

Create a file named `quota.yaml`:
```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: mem-cpu-demo
  namespace: ns-per-pod
spec:
  hard:
    requests.cpu: "1"
    requests.memory: 1Gi
    limits.cpu: "2"
    limits.memory: 2Gi
```

Now let's create `Pod`s in `default` namespace.

A `Pod` in the limits. Create a fole `pod-limited.yaml`:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: quota-mem-cpu-demo
  namespace: ns-per-pod
spec:
  containers:
  - name: quota-mem-cpu-demo-ctr
    image: nginx
    resources:
      limits:
        memory: "800Mi"
        cpu: "800m"
      requests:
        memory: "600Mi"
        cpu: "400m"
```

Run `kubectl apply -f pod-limited.yaml`

Let's see its status:
```
kubectl describe pod quota-mem-cpu-demo -n ns-per-pod
kubectl get pod quota-mem-cpu-demo -o yaml  -n ns-per-pod
```

Now let's create another one with the same YAML but we change the name:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: quota-mem-cpu-demo-2
  namespace: ns-per-pod
spec:
  containers:
  - name: quota-mem-cpu-demo-ctr
    image: nginx
    resources:
      limits:
        memory: "800Mi"
        cpu: "800m"
      requests:
        memory: "600Mi"
        cpu: "400m"
```

Run `kubectl apply -f pod-limited.yaml`

Cleanup: `kubectl delete ns ns-per-pod`

## Object Quotas

We can limit number of specific objects in the namespace.

Create a namespace:
```
kubectl create ns ns-object
```

Create a file called `object-quota.yaml`:
```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: pod-demo
  namespace: ns-object
spec:
  hard:
    pods: "2"
```

Let's see what happens when we'd like to create a `Deployment` with 3 replicas.

Create a file called `deployment.yaml`:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pod-quota-demo
  namespace: ns-object
spec:
  selector:
    matchLabels:
      purpose: quota-demo
  replicas: 3
  template:
    metadata:
      labels:
        purpose: quota-demo
    spec:
      containers:
      - name: pod-quota-demo
        image: spaster/alpine-sleep:latest
```

Run `kubectl apply -f deployment.yaml`

See status:
```
kubectl get deployment pod-quota-demo -o yaml -n ns-object
```

Cleanup: `kubectl delete ns ns-object`

# NetworkPolicy

We need to recreate the cluster with no built-in networking plugin and then install our own plugin that supports `NetworkPolicy`.

```
kubectl delete clusters kind
kubectl create cluster --config=new-kind-config.yaml
```

After it's done:
```
kubectl apply -f https://docs.projectcalico.org/v3.8/manifests/calico.yaml
kubectl -n kube-system set env daemonset/calico-node FELIX_IGNORELOOSERPF=true
```

Wait for it to complete:
```
kubectl get pods -n kube-system --watch
```

## Default Network Policies

Let's deploy Wordpress example.

```
kind load docker-image mysql:5.7
kind load docker-image wordpress:5.5.3
```

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mysql
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mysql
  serviceName: "mysql"
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
          volumeMounts:
          - name: mysql-pvc
            mountPath: /var/lib/mysql
  volumeClaimTemplates:
  - metadata:
      name: mysql-pvc
    spec:
      accessModes:
      - "ReadWriteOnce"
      resources:
        requests:
          storage: 1Gi
---
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
---
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
            value: "mysql:3306"
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
---
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

Let's see if it is up. Visit `localhost:30067`

Now we will limit all ingress traffic to pods.

Create a file called `denyall.yaml`:
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
spec:
  podSelector: {} # selects all pods.
  policyTypes:
  - Ingress
```

Check the connection by visiting `localhost:30067`

We will label our `Namespace` to be chosen correctly:
```
kubectl label ns default customer-id=1
```

Now we will allow only WP -> MySQL and Web -> WP access. Create a file called `netpol.yaml`:
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: db-network-policy
spec:
  podSelector:
    matchLabels:
      app: mysql
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          customer-id: "1"
    - podSelector:
        matchLabels:
          role: wp
    ports:
    - protocol: TCP
      port: 3306
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: wp-network-policy
spec:
  podSelector:
    matchLabels:
      app: wp
  policyTypes:
  - Ingress
  ingress:
  - from: []
    ports:
    - protocol: TCP
      port: 80
```

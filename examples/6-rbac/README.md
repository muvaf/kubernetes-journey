# RBAC

Let's create a `ServiceAccount`:
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: muvaffak
```

Now let's create a KUBECONFIG for that `ServiceAccount`:
```
./get-kubeconfig.sh muvaffak > tmp-cfg
```

Let's try to query something:
```
KUBECONFIG="$(pwd)/tmp-cfg" kubectl get pods
```

## Permissions for Namespaced Resources

A `Role` that gives access to read `Pod`s:
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
rules:
- apiGroups: [""] # "" indicates the core API group
  resources: ["pods"]
  verbs: ["get", "watch", "list"]
```

Now we will grant this `Role` to our `ServiceAccount`:
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-pods
subjects: # we can bind it to multiple subjects.
- kind: ServiceAccount
  name: muvaffak
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```


After doing a `kubectl apply` for both of those YAMLs, let's try again querying the pods:
```
KUBECONFIG="$(pwd)/tmp-cfg" kubectl get pods
```

## Permissions for Cluster-scoped Resources

`Node`, `PersistentVolume`...

Let's see if we can access `Node`:
```
KUBECONFIG="$(pwd)/tmp-cfg" kubectl get nodes
```

A `ClusterRole` that gives access to read `Node`s:
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: node-reader
rules:
- apiGroups: [""] # "" indicates the core API group
  resources: ["nodes"]
  verbs: ["get", "watch", "list"]
```

Now we will grant this `ClusterRole` to our `ServiceAccount`:
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: read-nodes
subjects: # we can bind it to multiple subjects.
- kind: ServiceAccount
  name: muvaffak
  namespace: default # need to give namespace since this is cluster-scoped object.
roleRef:
  kind: ClusterRole
  name: node-reader
  apiGroup: rbac.authorization.k8s.io
```

After doing a `kubectl apply` for these YAMLs, let's see if we can see `Node`s:
```
KUBECONFIG="$(pwd)/tmp-cfg" kubectl get nodes
```

## Accessing Kubernetes API Server from Pod

Let's create a `Pod` that has kubectl in it with a file called `pod.yaml`:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: kubectl-pod
spec:
  containers:
  - name: main
    image: bitnami/kubectl:1.19.4
    command:
    - "sleep"
    - "10000"
```

```
kubectl apply -f pod.yaml
```

Look at its service account name:
```
kubectl get pod kubectl-pod -o yaml
```

Now, let's go inside of that `Pod` and send some queries to API server:
```
kubectl exec -it kubectl-pod sh
```

We will give our earlier `ServiceAccount` to this `Pod` to use:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: kubectl-pod-2
spec:
  serviceAccountName: muvaffak
  containers:
  - name: main
    image: bitnami/kubectl:1.19.4
    command:
    - "sleep"
    - "10000"
```

```
kubectl exec -it kubectl-pod-2 sh
kubectl get pods
kubectl get nodes
kubectl get secret
```

We can see how Kubernetes mounts the `ServiceAccount` credentials:
```
printenv | grep KUBERNETES
ls /var/run/secrets/kubernetes.io/serviceaccount
```


We don't have to use `kubectl`!
```
TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
curl -X GET https://kubernetes:443/api/v1/namespaces/default/pods --header "Authorization: Bearer $TOKEN" --insecure
```

## Limit to One Resource

We don't have to allow every instance of given kind.

Let's create a `Secret`:
```
kubectl create secret generic mysecret --from-literal=username=root --form-literal=password=pass123
```

We'd like to give a `Pod` API access to secret but we don't want it to access other secrets:
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: secret-reader
rules:
- apiGroups: [""] # "" indicates the core API group
  resources: 
  - secrets
  resourceNames:
  - mysecret
  verbs:
  - get
  - watch
  - list
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-secret
subjects: # we can bind it to multiple subjects.
- kind: ServiceAccount
  name: muvaffak
roleRef:
  kind: Role
  name: secret-reader
  apiGroup: rbac.authorization.k8s.io
```

Now, let's go back into the `Pod` and fetch that secret.

```
TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
curl -X GET https://kubernetes:443/api/v1/namespaces/default/secrets/mysecret --header "Authorization: Bearer $TOKEN" --insecure
```

Let's try to see other `Secret`s:
```
curl -X GET https://kubernetes:443/api/v1/namespaces/default/secrets --header "Authorization: Bearer $TOKEN" --insecure
```
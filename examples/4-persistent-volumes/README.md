# Persistent Volumes

## Dynamic Provisioning

First we need a `StorageClass` present in the cluster that will tell Kubernetes how to get the storage.

```
kubectl describe storageclass standard
```

Now let's request a persistent volume using `PersistentVolumeClaim`.
Create `pvc.yaml`:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mypvc
spec:
  storageClassName: standard # optional
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
```

Let's see its status:
```
kubectl describe pvc mypvc
```

> In kind cluster, it doesn't create the storage until a `Pod` is created to consume it.

Let's create a `pod.yaml` that consumes this PVC:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pvc-example
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
    persistentVolumeClaim:
      claimName: mypvc
```

Now let's see the created `PersistentVolume`:
```
kubectl get persistentvolume
kubectl describe persistentvolume pvc-0ab356b8-b027-461a-9d40-78d9818e049a
```

## Static Provisioning

There are cases where you want to create a bunch of storage and developers would come in and use the ones that are available. In this case, we don't need a `StorageClass`.

Let's create a file named `pv.yaml`:
```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: some-pv
spec:
  accessModes:
  - ReadWriteOnce
  capacity:
    storage: 1Gi
  hostPath:
    path: /var/local-path-provisioner/some-pv
    type: DirectoryOrCreate
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - kind-control-plane
  persistentVolumeReclaimPolicy: Delete
  storageClassName: standard
  volumeMode: Filesystem
```

Now we have the `PersistentVolume`, we can claim it with a `PersistentVolumeClaim` statically.

Create `pod-pvc-static.yaml`
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: static-example
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
    persistentVolumeClaim:
      claimName: another-pvc
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: another-pvc
spec:
  accessModes:
      - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  volumeMode: Filesystem
  volumeName: some-pv # manually populated the name here
```
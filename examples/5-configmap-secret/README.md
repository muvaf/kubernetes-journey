# ConfigMap

Let's create a `ConfigMap`.

Create a file named `configmap.yaml`:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: myconfig
data:
  enableAwesomeFeature: "true"
  numberOfPlayers: "3"
```

Run `kubectl apply -f configmap.yaml`

## As Env Var

Let's create an app that reads some env vars.

Create `reader.sh`:
```
#!/bin/sh
echo "Value of ENVVAR1: ${ENVVAR1}"
echo "Value of ENVVAR2: ${ENVVAR2}"
```

Create a Dockerfile named `Dockerfile` to build:
```Dockerfile
FROM alpine:latest
COPY reader.sh reader.sh
RUN chmod +x reader.sh
CMD ["./reader.sh"]
```

Build and load:
```
docker build -t reader:1.0 .
kind load docker-image reader:1.0
```

Now let's use our `ConfigMap` to supply an environment variable.

Create a file called `pod-env.yaml`
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: reader-1
spec:
  containers:
    - name: reader
      image: reader:1.0
      env:
      - name: ENVVAR1
        valueFrom:
          configMapKeyRef:
            name: myconfig
            key: enableAwesomeFeature
      - name: ENVVAR2
        valueFrom:
          configMapKeyRef:
            name: myconfig
            key: numberOfPlayers
```

Let's run it!
```
kubectl apply -f pod-env.yaml
kubectl logs reader-1
```

## As Args to Container

Let's change `reader.sh` to print arguments:
```bash
#!/bin/sh
echo "Value of first argument: ${1}"
echo "Value of second argument: ${2}"
```

Build and load:
```
docker build -t reader:2.0 .
kind load docker-image reader:2.0
```

Create a file called `pod-args.yaml`
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: reader-2
spec:
  containers:
    - name: reader
      image: reader:2.0
      command:
      - "reader.sh"
      - "$(ENVVAR1)"
      - "$(ENVVAR2)"
      env:
      - name: ENVVAR1
        valueFrom:
          configMapKeyRef:
            name: myconfig
            key: enableAwesomeFeature
      - name: ENVVAR2
        valueFrom:
          configMapKeyRef:
            name: myconfig
            key: numberOfPlayers
```

Let's create it:
```
kubectl apply -f pod-args.yaml
kubectl logs reader-2
```

## As Files in Volume

We can actually treat `ConfigMap`s as volumes.

Let's make some changes to reader so that it reads from file:
```bash
#!/bin/sh
echo "Content of first file: $(cat /tmp/cfg/thefeature)"
echo "Content of second file: $(cat /tmp/cfg/playerCount)"
```

Build and load:
```
docker build -t reader:3.0 .
kind load docker-image reader:3.0
```

Create a file called `pod-volume.yaml`
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: reader-3
spec:
  containers:
    - name: reader
      image: reader:3.0
      volumeMounts:
      - name: config
        mountPath: "/tmp/cfg"
        readOnly: true
  volumes:
  - name: config
    configMap:
      name: myconfig
      items:
      - key: enableAwesomeFeature
        path: thefeature
      - key: numberOfPlayers
        path: playerCount
```

Let's create it:
```
kubectl apply -f pod-volume.yaml
kubectl logs reader-3
```

Cleanup:
```
kubectl delete pods --all
kubectl delete configmap --all
```

# Secret

Several ways to create a secret.

```
kubectl create secret generic mysecret --from-literal=username=root --form-literal=password=pass123
kubectl describe secret mysecret
kubectl get secret mysecret -o yaml
```

We can create via a YAML file. However, we need to base64 encode it first.
```
echo "root" | base64
echo "pass123" | base64
```

Now let's create a `secret.yaml`:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: myothersecret
data:
  username: <base64 encoded value>
  password: <base64 encoded value>
```

Alternatively, we can use `stringData` field. Create `secret-string.yaml`:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: myothersecret
stringData:
  username: root
  password: pass123
```

However, this will be converted to base64 in the cluster.

Let's create this:
```
kubectl apply -f secret-string.yaml
kubectl describe secret myothersecret
```

## As Env Var

Create a file called `pod-secret-env.yaml`
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: reader-1
spec:
  containers:
    - name: reader
      image: reader:1.0
      env:
      - name: ENVVAR1
        valueFrom:
          secretKeyRef:
            name: mysecret
            key: username
      - name: ENVVAR2
        valueFrom:
          secretKeyRef:
            name: mysecret
            key: password
```

Let's run it!
```
kubectl apply -f pod-secret-env.yaml
kubectl logs reader-1
```

## As Args to Cmd

Create a file called `pod-secret-args.yaml`
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: reader-2
spec:
  containers:
    - name: reader
      image: reader:2.0
      command:
      - "reader.sh"
      - "$(ENVVAR1)"
      - "$(ENVVAR2)"
      env:
      - name: ENVVAR1
        valueFrom:
          secretKeyRef:
            name: mysecret
            key: username
      - name: ENVVAR2
        valueFrom:
          secretKeyRef:
            name: mysecret
            key: password
```

Let's create it:
```
kubectl apply -f pod-secret-args.yaml
kubectl logs reader-2
```

## As Volume

Create a file called `pod-secret-volume.yaml`
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: reader-3
spec:
  containers:
    - name: reader
      image: reader:3.0
      volumeMounts:
      - name: secret
        mountPath: "/tmp/cfg"
        readOnly: true
  volumes:
  - name: secret
    secret:
      secretName: mysecret
```

Let's create it:
```
kubectl apply -f pod-volume.yaml
kubectl logs reader-3
```

# Wordpress Exercise

Let's deploy a Wordpress with MySQL using `Secret`s for credentials, `Service`s for access, `PersistentVolumeClaim` for storage, and `Deployment` & `StatefulSet` for workload!
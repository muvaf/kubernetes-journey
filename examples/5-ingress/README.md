# Ingress

Install nginx-ingress controller:
```
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/provider/kind/deploy.yaml
```

Now let's deploy two `Service`s with `Pod`s.

Create `pods.yaml`:
```yaml
kind: Pod
apiVersion: v1
metadata:
  name: apple-app
  labels:
    app: apple
spec:
  containers:
    - name: apple-app
      image: hashicorp/http-echo
      args:
        - "-text=apple"
---
kind: Service
apiVersion: v1
metadata:
  name: apple-service
spec:
  selector:
    app: apple
  ports:
    - port: 5678 # Default port for image
---
kind: Pod
apiVersion: v1
metadata:
  name: banana-app
  labels:
    app: banana
spec:
  containers:
    - name: banana-app
      image: hashicorp/http-echo
      args:
        - "-text=banana"
---
kind: Service
apiVersion: v1
metadata:
  name: banana-service
spec:
  selector:
    app: banana
  ports:
    - port: 5678 # Default port for image
```

Check them by openning tunnels:
```
kubectl port-forward banana-app 8080:5678
kubectl port-forward apple-app 8081:5678
```
```
curl localhost:8081
curl localhost:8080
```

Now let's create an `Ingress` in a file called `ingress.yaml`:
```yaml
apiVersion: networking.k8s.io/v1beta1
kind: Ingress
metadata:
  name: example-ingress
  annotations:
    ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
  - http:
      paths:
        - path: /apple
          backend:
            serviceName: apple-service
            servicePort: 5678
        - path: /banana
          backend:
            serviceName: banana-service
            servicePort: 5678
```

Go visit `localhost/apple` and `localhost/banana`

We can also add `host` like `foo.bar.com` to the `rules`.

## SSL

Let's generate a self-signed certificate:
```
KEY_FILE=key.ssl
CERT_FILE=cert.ssl
HOST=localhost
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout ${KEY_FILE} -out ${CERT_FILE} -subj "/CN=${HOST}/O=${HOST}"
```

Store it in a `Secret`:
```
kubectl create secret tls mycert --key ${KEY_FILE} --cert ${CERT_FILE}
```

Now let's give that SSL certificate to nginx-controller.

Create `ingress-ssl.yaml`:
```yaml
apiVersion: networking.k8s.io/v1beta1
kind: Ingress
metadata:
  name: example-ingress
  annotations:
    ingress.kubernetes.io/rewrite-target: /
spec:
  tls:
  - hosts:
    - localhost
    secretName: mysecret
  rules:
  - http:
      host: localhost
      paths:
        - path: /apple
          backend:
            serviceName: apple-service
            servicePort: 5678
        - path: /banana
          backend:
            serviceName: banana-service
            servicePort: 5678
```

Go visit `https://localhost/apple`

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
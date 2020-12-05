# Using Kubeadm

## Common for All Nodes

Make sure `/etc/sysctl.d/k8s.conf` file is created and has content:
```
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
```

We need to disable Swap so that memory limits are respected:
```
sudo swapoff -a
```

Disable it permanently, make sure all swaps are gone in `/etc/fstab`

### Container Runtime

Various container-runtimes. We will install Docker to every node.
```
sudo apt-get install \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

# This line depends on architecture. It's different if CPU is ARM-based.
sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io
```

Check if it's running:
```
sudo docker run hello-world
sudo docker rm hello-world
```

### Kubernetes Tools

Install `kubeadm`, `kubectl` and `kubelet` to all nodes.

```
sudo apt-get update && sudo apt-get install -y apt-transport-https curl
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
cat <<EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
```

## Initialize Master

We will initialize master node.

```
sudo kubeadm init --control-plane-endpoint 192.168.1.45 --pod-network-cidr=10.244.0.0/16
```

After this is completed, there will be a command in the output to run in all nodes like the following:
```
kubeadm join <control-plane-host>:<control-plane-port> --token <token> --discovery-token-ca-cert-hash sha256:<hash>
```

We will run this command in **every machine**. Take note of it.

Now let's get the admin KUBECONFIG of this cluster:
```
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

See the content:
```
cat $HOME/.kube/config
```

### Install Networking Plugin

We need a networking plugin so that pods can talk to each other. Let's use Flannel:
```
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
```

### Install Service Discovery Plugin

Check if CoreDNS is installed `kubectl get pods -n kube-system`. If the installation wasn't customized, it should be installed by default.

## Initialize Nodes

Now go ahead and run the command from `kubeadm init` output in every node. The tokens work for 24 hours. For joining late, you can create new tokens with `kubectl token create`

### Install Ingress Controller

We will install nginx-controller:
```
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v0.41.2/deploy/static/provider/baremetal/deploy.yaml
```

Note that this uses `NodePort`s for routing by default. We can install load balancer for external IP assignment.

### Install LoadBalancer

We will use MetalLB to receive the external traffic from the external IP and bring it into the cluster.

```
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.9.5/manifests/namespace.yaml
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.9.5/manifests/metallb.yaml
# On first install only
kubectl create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)"
```

We will do a Layer 2 configuration for MetalLB:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: metallb-system
  name: config
data:
  config: |
    address-pools:
    - name: default
      protocol: layer2
      addresses:
      - 192.168.1.240-192.168.1.250
```

This will assign a new IP in the network for all `LoadBalancer` type `Service`s. Then in the router, we can map public ports to that IP address.

### Install Dashboard (optional)

We can install it via:
```
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.5/aio/deploy/recommended.yaml
```

Then in our local, we can open a proxy to cluster (or a tunnel to dashboard pod):
```
kubectl proxy
```

Now login to the Dashboard:
```
http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/
```

## Try out Wordpress!

Do all steps in the earlier examples. Optionally we can use Let's Encrypt to get trusted certificates.

We'll use `cert-manager` to manage our certificates.
```
kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v0.16.1/cert-manager.yaml
```
```
kubectl get pods --namespace cert-manager -w
```

Create a file called `prod-issuer.yaml`:
```yaml
apiVersion: cert-manager.io/v1alpha2
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
  namespace: cert-manager
spec:
  acme:
    # The ACME server URL
    server: https://acme-v02.api.letsencrypt.org/directory
    # Email address used for ACME registration
    email: onus.muvaffak@gmail.com
    # Name of a secret used to store the ACME account private key
    privateKeySecretRef:
      name: letsencrypt-prod
    # Enable the HTTP-01 challenge provider
    solvers:
    - http01:
        ingress:
          class: nginx
```

Now, let's use a `LoadBalancer` service to use this certificate for all traffic coming to ingress-nginx-controller:
```yaml
apiVersion: v1
kind: Service
metadata:
  annotations:
    service.beta.kubernetes.io/do-loadbalancer-enable-proxy-protocol: "true"
    service.beta.kubernetes.io/do-loadbalancer-hostname: "home.muvaf.com"
  labels:
    helm.sh/chart: ingress-nginx-2.11.1
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/instance: ingress-nginx
    app.kubernetes.io/version: 0.34.1
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/component: controller
  name: ingress-nginx-controller
  namespace: ingress-nginx
spec:
  type: LoadBalancer
  externalTrafficPolicy: Local
  ports:
    - name: http
      port: 80
      protocol: TCP
      targetPort: http
    - name: https
      port: 443
      protocol: TCP
      targetPort: https
  selector:
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/instance: ingress-nginx
    app.kubernetes.io/component: controller
```

Get the TLS secret name from Certificate resource.
```
kubectl describe certificate
```

Edit the Wordpress Ingress:
```yaml
apiVersion: networking.k8s.io/v1beta1
kind: Ingress
metadata:
  name: echo-ingress
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  tls:
  - hosts:
    - home.muvaf.com
    secretName: echo-tls
  rules:
  - host: home.muvaf.com
    http:
      paths:
      - backend:
          serviceName: wp
          servicePort: 80
```

Let's visit `https://home.muvaf.com`
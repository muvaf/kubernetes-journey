# StatefulSet

Let's create a MySQL database with its own volume.

Create a file named `mysql.yaml`:
```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mysql
spec:
  replicas: 1
  serviceName: mysql
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
```

Run `kubectl apply -f mysql.yaml`

```
kubectl get pods
kubectl get pvc
kubect get pv
```

Now, let's deploy Wordpress:
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

Now access `localhost:30067`!

Let's delete all we created directly:
```
kubectl delete -f wp.yaml -f mysql.yaml
```

Let's see if PVC and PV are still there:
```
kubectl get pvc
kubectl get pv
```

# Helm

Install Helm:

MacOS:
```
brew install helm
```
Linux:
```
curl https://baltocdn.com/helm/signing.asc | sudo apt-key add -
sudo apt-get install apt-transport-https --yes
echo "deb https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
sudo apt-get install helm
```

Windows:
```
choco install kubernetes-helm
```

Create a new folder and initialize boilerplate:
```
helm create mychart
```

Clean up the `templates` folder and write Wordpress YAMLs.

Create `mysql.yaml`:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: {{ .Values.ReleaseName }}-db-auth
stringData:
  rootPassword: {{ .Values.databaseRootPassword }}
  databaseName: {{ .Values.databaseName }}
  username: {{ .Values.databaseUsername }}
  password: {{ .Values.databasePassword }}
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: {{ .Values.ReleaseName }}-mysql
spec:
  replicas: 1
  serviceName: "{{ .Values.ReleaseName }}-mysql"
  selector:
    matchLabels:
      app: {{ .Values.ReleaseName }}-mysql
  template:
    metadata:
      labels:
        app: {{ .Values.ReleaseName }}-mysql
    spec:
      containers:
        - name: server
          image: mysql:5.7
          env:
          - name: MYSQL_ROOT_PASSWORD
            valueFrom:
              secretKeyRef:
                name: db-auth
                key: rootPassword
          - name: MYSQL_DATABASE
            valueFrom:
              secretKeyRef:
                name: db-auth
                key: databaseName
          - name: MYSQL_USER
            valueFrom:
              secretKeyRef:
                name: db-auth
                key: username
          - name: MYSQL_PASSWORD
            valueFrom:
              secretKeyRef:
                name: db-auth
                key: password
          ports:
            - name: mysql
              containerPort: 3306
              protocol: TCP
          volumeMounts:
          - name: {{ .Values.ReleaseName }}-mysql-pvc
            mountPath: /var/lib/mysql
  volumeClaimTemplates:
  - metadata:
      name: {{ .Values.ReleaseName }}-mysql-pvc
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
  name: {{ .Values.ReleaseName }}-mysql
spec:
  type: ClusterIP
  selector:
    app: {{ .Values.ReleaseName }}-mysql
  ports:
    - port: 3306
```

Create `wp.yaml`:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Values.ReleaseName }}-wp
spec:
  replicas: 1
  selector:
    matchLabels:
      app: {{ .Values.ReleaseName }}-wp
  template:
    metadata:
      labels:
        app: {{ .Values.ReleaseName }}-wp
    spec:
      containers:
        - name: wordpress
          image: wordpress:5.5.3
          env:
          - name: WORDPRESS_DB_HOST
            value: "mysql:3306"
          - name: WORDPRESS_DB_NAME
            valueFrom:
              secretKeyRef:
                name: db-auth
                key: databaseName
          - name: WORDPRESS_DB_USER
            valueFrom:
              secretKeyRef:
                name: db-auth
                key: username
          - name: WORDPRESS_DB_PASSWORD
            valueFrom:
              secretKeyRef:
                name: db-auth
                key: password
          ports:
            - name: wp
              containerPort: 80
              protocol: TCP
---
apiVersion: v1
kind: Service
metadata:
  name: {{ .Values.ReleaseName }}-wp
spec:
  type: NodePort
  selector:
    app: {{ .Values.ReleaseName }}-wp
  ports:
    - port: 80
      nodePort: {{ .Values.wordpressNodePort | default 30067 }}
```

Let's write our `values.yaml` in the main directory:
```yaml
wordpressNodePort: 30067
databaseRootPassword: root
databaseName: wp-db
databaseUsername: wp-user
databasePassword: wp-password
```

Let's try installing it:
```
helm install -f values.yaml .
```

```
helm ls
```

Check if everything is working.

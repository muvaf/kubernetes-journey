# Deploy Wordress with Compose

MySQL image ( `mysql:5.7` ) expects the following env vars:
```
MYSQL_ROOT_PASSWORD: somewordpress
MYSQL_DATABASE: wordpress
MYSQL_USER: wordpress
MYSQL_PASSWORD: wordpress
```

By default it uses `/var/lib/mysql` path as data store.

Wordpress image  ( `wordpress:latest` ) expects the following env vars:
```
WORDPRESS_DB_HOST: db:3306
WORDPRESS_DB_USER: wordpress
WORDPRESS_DB_PASSWORD: wordpress
WORDPRESS_DB_NAME: wordpress
```

## Deploy without a Volume

Write a `docker-compose.stateless.yaml` to deploy a Wordpress without a volume.

## Deploy using a Volume

Write a `docker-compose.yaml` to deploy Wordpress with persistent storage.

A volume example:
```yaml
version: "3.8"
services:
  web:
    volumes:
    - db_data:/pathforvolume
    ...
volumes:
  db_data: {} # no option
```
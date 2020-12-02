# Docker Compose Example

## Single Project

The application code lives in `app.py`:
```python
import time
import os

import redis
from flask import Flask

app = Flask(__name__)
cache = redis.Redis(host=os.getenv("REDIS_URL", "redis"), port=6379)

def get_hit_count():
    retries = 5
    while True:
        try:
            return cache.incr('hits')
        except redis.exceptions.ConnectionError as exc:
            if retries == 0:
                raise exc
            retries -= 1
            time.sleep(0.5)

@app.route('/')
def hello():
    count = get_hit_count()
    return 'Hello World! I have been seen {} times.\n'.format(count)

```

Dependencies of this program are in `requirements.txt`:
```
redis
flask
```

Building our Python app:
```Dockerfile
FROM python:3.7-alpine

RUN apk add --no-cache gcc musl-dev linux-headers

WORKDIR /code

ENV FLASK_APP=app.py
ENV FLASK_RUN_HOST=0.0.0.0

COPY . .
RUN pip install -r requirements.txt

EXPOSE 5000
CMD ["flask", "run"]
```

Our app will use the official Redis image as its data store. Let's compose them.

```yaml
version: "3.8"
services:
  web:
    build: .
    ports:
      - "5000:5000"
  redis:
    image: "redis:alpine" # does not expose any port.
```

Run!

```console
docker-compose up --detach
docker-compose ps
```

# Multiple Projects

We can start it with another name but we need to change the port. To automatize, we can use variable name.

```yaml
version: "3.8"
services:
  web:
    build: .
    ports:
      - "${PORT}:5000"
  redis:
    image: "redis:alpine" # does not expose any port.
```

Now let's run this alongside the first one.

```console
PORT=8080 docker-compose --project-name second -f docker-compose.var.yaml up -d
docker-compose -p another ps
```


## Environment Variables in Containers

Just like we give ENV during build, we can supply environment variables during run as well.

```yaml
version: "3.8"
services:
  web:
    environment:
      FLASK_ENV: development
    build: .
    ports:
      - "${PORT}:5000"
  redis:
    image: "redis:alpine"
```

The alternative would be:
```console
docker run --env ....
```

Let's run with env var:
```console
PORT=8081 docker-compose -p third -f docker-compose.env.yaml up -d 
```

```yaml
docker logs third_web_1
```

We can also give a full file of env vars:
```yaml
version: "3.8"
services:
  web:
    env_file:
    - dev.env
    build: .
    ports:
      - "${PORT}:5000"
  redis:
    image: "redis:alpine"
```

`dev.env` could look like:
```
FLASK_DEV=development
```

## Update Project

Make a change in `app.py` by changing the return value.

```console
PORT=8081 docker-compose -p third -f docker-compose.var.yaml up -d --build
```

Go visit `http://0.0.0.0:8081/`

Cleanup:
```console
docker-compose down
docker-compose -p second down
docker-compose -p third down
```

## Different Environments

We may want different configurations depending on the environment like Dev, Staging, Prod etc.

Original:
```yaml
version: "3.8"
services:
  web:
    environment:
      FLASK_ENV: development
    build: .
    ports:
      - "${PORT}:5000"
  redis:
    image: "redis:alpine"
```

We can have a file to be used in prod named `docker-compose.prod.yaml`:
```yaml
version: "3.8"
services:
  web:
    environment:
      FLASK_ENV: production
      ports: "80:5000"
```

Let's deploy two files together:
```console
PORT=8081 docker-compose -p prod -f docker-compose.env.yaml -f docker-compose.prod.yaml up --detach
```

```yaml
docker logs prod_web_1
```

## Custom Networks

Create a `docker-compose.network.yaml`:
```yaml
version: "3.8"
services:
  web:
    environment:
      FLASK_ENV: development
    build: .
    ports:
      - "8080:5000"
    networks:
      - first
  redis:
    image: "redis:alpine"
    networks:
      - first
  web2:
    environment:
      FLASK_ENV: development
    build: .
    ports:
      - "8081:5000"
    networks:
      - second
  redis2:
    image: "redis:alpine"
    networks:
      - second
networks:
  first:
    driver: bridge
  second:
    driver: bridge
```

Let's run this and see if records are different:
```console
docker-compose -p network -f docker-compose.network.yaml up --detach
```

## Dependencies

The application needs to be resilient about unavailability. However, there are cases where that's not really possible or out of your control.

We can define a startup and shutdown order.

Write `docker-compose.dependency.yaml`
```yaml
version: "3.8"
services:
  web:
    build: .
    ports:
      - "8080:5000"
    depends_on:
      - "redis"
  redis:
    image: "redis:alpine"
```

```console
docker-compose -p network -f docker-compose.dependency.yaml up
```

You can also add a wrapper script to make sure it's actually ready to accept connections rather than just being running:

```yaml
version: "3.8"
services:
  web:
    build: .
    ports:
      - "8080:5000"
    depends_on:
      - "redis"
    command: ["./wait-for-it.sh", "redis:6379", "--", "python", "app.py"]
  redis:
    image: "redis:alpine"
```

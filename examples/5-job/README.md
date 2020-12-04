# Job

Create cluster with the following command:
```
kind create cluster --config=kind-config.yaml
```

## Successful Job

Let's write a script that will complete successfully.

Create a `success.sh`
```bash
#!/bin/sh
echo "Started!"
sleep 5
echo "Phase 1 completed!"
sleep 5
echo "Phase 2 completed!"
sleep 5
echo "Success!"
```

Let's build a Docker image for it named `Dockerfile.success`:
```Dockerfile
FROM alpine:latest

COPY success.sh success.sh

RUN chmod +x success.sh

CMD ["./success.sh"]
```

Build and load into the cluster:
```
docker build -t success:1.0 -f Dockerfile.success .
kind load docker-image success:1.0
```

Now let's create a `job.yaml`:
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: pi-1
spec:
  template:
    spec:
      containers:
      - name: phases
        image: success:1.0
      restartPolicy: Never
  backoffLimit: 4
```

Run `kubectl apply -f job.yaml`

Check its status:
```
kubectl get pods
kubectl get jobs
```

## Failed Job

Now let's do it for a script that will fail eventually:
```bash
#!/bin/sh
echo "Started!"
sleep 5
echo "Phase 1 completed!"
sleep 5
echo "Phase 1 failed!"
exit 1
```

Let's build a Docker image for it named `Dockerfile.fail`:
```Dockerfile
FROM alpine:latest

COPY fail.sh fail.sh

RUN chmod +x fail.sh

CMD ["./fail.sh"]
```

Build and load into the cluster:
```
docker build -t fail:1.0 -f Dockerfile.fail .
kind load docker-image fail:1.0
```

Now let's create a `job-fail.yaml`:
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: pi-2
spec:
  template:
    spec:
      containers:
      - name: phases
        image: fail:1.0
      restartPolicy: Never
  backoffLimit: 4
```

Run `kubectl apply -f job-fail.yaml`

Check its status:
```
kubectl get pods
kubectl get jobs
```

## Multiple Completions

Let's say we'd like to run the workload more than 1.

Create `job-completion.yaml`:
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: pi-3
spec:
  template:
    spec:
      containers:
      - name: phases
        image: success:1.0
      restartPolicy: Never
  backoffLimit: 4
  completion: 3
```

Run `kubectl apply -f job-completion.yaml`

See the status:
```
kubectl get pods --watch
kubectl get jobs
```

## Active Deadline Seconds

We can limit the time that a `Job` runs. If it takes more, Kubernetes will kill it.

Create `job-deadline.yaml`:
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: pi-4
spec:
  template:
    spec:
      containers:
      - name: phases
        image: success:1.0
      restartPolicy: Never
  backoffLimit: 4
  activeDeadlineSeconds: 5
```

Run `kubectl apply -f job-deadline.yaml`

Let's check the status:
```
kubectl get pods -w
kubectl get jobs
```

## Cleanup After Completion

Create `job-cleanup.yaml`:
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: pi-5
spec:
  ttlSecondsAfterFinished: 20
  template:
    spec:
      containers:
      - name: phases
        image: success:1.0
      restartPolicy: Never
  backoffLimit: 4
```

Run `kubectl apply -f job-cleanup.yaml`

# CronJob

Create `cronjob.yaml`:
```yaml
apiVersion: batch/v1beta1
kind: CronJob
metadata:
  name: hello
spec:
  schedule: "*/1 * * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: hello
            image: busybox
            imagePullPolicy: IfNotPresent
            args:
            - /bin/sh
            - -c
            - date; echo Hello from the Kubernetes cluster
          restartPolicy: OnFailure
```

Every minute a new `Job` will be created. Watch:
```
kubectl get pods
kubectl get jobs --watch
```

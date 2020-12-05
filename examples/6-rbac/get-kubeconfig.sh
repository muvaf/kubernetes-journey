#!/bin/bash
set -eE

# jq has to be installed.

SA_NAME=${1}

SECRET_NAME=$(kubectl get serviceaccount ${SA_NAME} -o jsonpath='{.secrets[0].name}')
CERT_AUTH_DATA=$(kubectl get secret ${SECRET_NAME} -o jsonpath='{.data.ca\.crt}')
TOKEN=$(kubectl get secret ${SECRET_NAME} -o jsonpath='{.data.token}' | base64 -D)
CONTEXT=$(kubectl config current-context)
URL=$(kubectl config view -o json | jq ".clusters[] | select(.name == \"${CONTEXT}\")" | jq '.cluster.server')

echo "apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: ${CERT_AUTH_DATA}
    server: ${URL}
  name: kind-kind
contexts:
- context:
    cluster: kind-kind
    namespace: default
    user: ${SA_NAME}
  name: ${SA_NAME}
current-context: ${SA_NAME}
kind: Config
preferences: {}
users:
- name: ${SA_NAME}
  user:
    token: ${TOKEN}"
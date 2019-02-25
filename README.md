[![Build Status](https://travis-ci.com/equinor/sdp-flux.svg?token=yR5pmi3sbtpmzTWwTfNG&branch=master)](https://travis-ci.com/equinor/sdp-flux)

# Repository used for Kubernetes GitOps
This is the repository where we define the manifest to be run in Kubernetes. We use [Flux](https://github.com/weaveworks/flux) as the basis for our GitOps workflow. 

## How it works
In essence we create manifests to be run on the Kubernetes cluster, commit them to this repository and then the Flux controller notices the new commit and applies all the YAML files (can be simplified down to `kubectl apply -f FILENAME`).

## How we use it
In production we never commit straight to the repository, always create a new branch (or use your existing) (`git branch -b new_branch_name`) modify what you want changed or implement your new feature, commit (`git add . && git commit -m 'commit message'`) and then push to remote (`git push -u origin new_branch_name`). After all this editing, commit and pushing you need to create a pull-request so that you, but preferably another on your team can see review the changes and merge the files.

__TODO__: Find a procedure for testing the code before commiting and running on prod.

## Naming conventions
This readme should always be called README.md and be placed on the root. In addition to this readme we have docs in the `docs` folder. The `custom-charts` folder contains the charts we have created ourselves and and is needed for our cluster. The creation of new namespaces is done by creating a new file with the same name as the namespace(.yaml) and place it under the folder `namespaces`.

The different applications and workloads we run is placed in the folder with the same name as their namespace. E.g. sdp-demo should be run in staging namespace and is therefore placed `staging/sdp-demo.yaml`. For all services that can be described and run from one manifest should have the same name as the workload(.yaml) under namespace folder. If multiple manifests is needed a directory should be created and files placed inside. Preferably the manifest should be named as per the kind, e.g. helmrelease.yaml if only one resource of this kind is created.

## Using Sealed Secrets
Sometimes we need to store secrets in the Git repository to make sure our repository is the primary source of truth. In these cases we use a system called [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets). With this system we can store secrets enrypted in the repository and be sure that Flux manages and puts them in the Kubernetes cluster

### Install client

- Download [kubeseal](https://github.com/bitnami-labs/sealed-secrets/releases)
- Put `kubeseal-linux-amd64` or `kubeseal-darwin-amd64` in your path and rename it to `kubeseal`.

### First time
After first run we need to export the private and public key. The public key is what we all use to encrypt the secrets and the private key is used by the controller to decrypt the secrets and put them in the cluster. It is important to have a backup of the private key, but _NEVER_ commit that to the repository.

- To get the private key (remember to store this file somewhere safe so we can restore in case of emergency)
  `kubectl get secret -n infrastructure sealed-secrets-key -o yaml > sealedsecrets.yaml`

- Use the kubeseal tool to get the public key
  `kubeseal --controller-namespace infrastructure --controller-name sealed-secrets --fetch-cert > secret.pem`

### Daily usage
You need to use the kubectl to initially create the secret and then pipe this to kubeseal to make it encrypted.
```
# To use from literal
kubectl -n NAMESPACE create secret generic SECRETNAME --dry-run --from-literal=KEY=VALUES -o json | kubeseal --format yaml --cert secret.pem > SECRETNAME.yaml

# To use from file
kubectl -n NAMESPACE create secret generic SECRETNAME --dry-run --from-file=FILENAME -o json | kubeseal --cert secret.pem --format yaml > SECRETNAME.yaml

# To create TLS secret
kubectl create secret tls SECRETNAME --key mycert.key --cert mycert.crt --dry-run -o json | kubeseal --format yaml --cert secret.pem > sealed-secret-tls.yaml
```
Make sure to place the secrets in the appropriate namespace folder to keep the repository organised.
## Oauth2 Proxy
To utilize oauth2-proxy to authenticate users before they can access a web application, add these lines to the **ingress annotation**:
``` 
nginx.ingress.kubernetes.io/auth-url: "https://$host/oauth2/auth"
nginx.ingress.kubernetes.io/auth-signin: "https://$host/oauth2/start?rd=$escaped_request_uri"
```
You also need a **host specific ingress for the proxy**. That could look like [this](examples/oauth2-ingress.yaml).

There is also a few more things to note;
* The oauth2-proxy need to be deployed in the same namespace
* The proxy must be configured with the specific Azure app. This is where we define access. Each proxy can only authenticate *one* application.
* Note that in Helm version < v3, the name of a helm release must be uniq in the *cluster*, NOT within a *namespace*. So to deploy multiple oauth2-proxy instances, the helm release name must be different, the service name will also change.
### Configure Oauth2-proxy
To deploy a new oauth2-proxy using our custom Helm chart.  
Note the *azure_tenant* container argument and the *envFromSecret*. The envFromSecret should point to a *single secret* containing these keys:
* OAUTH2_PROXY_CLIENT_ID
* OAUTH2_PROXY_CLIENT_SECRET
* OAUTH2_PROXY_COOKIE_SECRET
```
kind: HelmRelease
  values:
    container:
      args:
        azure_tenant: 3aa4a235-b6e2-48d5-9195-7fcf05b459b0
    envFromSecret: oauth2-proxy-secret
```
The cookie secret can be created like this;  
`docker run -ti --rm python:3-alpine python -c 'import secrets,base64; print(base64.b64encode(base64.b64encode(secrets.token_bytes(16))));'`

You only need to copy the content after b'<JUST FROM HERE>'.

## Tips and tricks
How to do something we do a lot? If you know, type them up here and we shall all be the wiser for it.

### Using Azure Container Registry
We assume the ACR has been created and set up in the bootstrapping portion of the Kubernetes cluster. Take a look in sdp-aks repository for information on how to create and set up a new ACR. To use the ACR we need a service principal that also should have been created in bootstrap.

- Start by creating the secret which stores docker registry information
  `kubectl -n NAMESPACE create secret docker-registry SECRET_NAME --docker-server=REGISTRY_URL --docker-username=SERVICE_PRINCIPAL_ID --docker-password=SERVICE_PRINCIPAL_PASSWORD --docker-email=gm_sds_rdi@equinor.com`

- The usual way to use this is to create a chart that has support for [imagePullSecrets](https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/). View the sdp-demo chart as an example reference.
  We need to define image to a tagged image in our ACR and the imagePullSecrets need to reference our newly created secret.

A example Pod
```
apiVersion: v1
kind: Pod
metadata:
  name: private-reg
spec:
  containers:
  - name: private-reg-container
    image: REGISTRY_URL/<your-private-image>
  imagePullSecrets:
  - name: SECRET_NAME
```

For more read [docs/ACR.md](docs/ACR.md).

### Produce certificates from ingress config (Cert Manager)
We use [Cert Manager](https://github.com/jetstack/cert-manager) for creating, validating and deploying Lets Encrypt certificates. Cert Manager can shortcut the usuall procedure of creating a Certificate resource and then referencing the secret from this Certificate in the ingress by adding a few annotations to the ingress.

In the shortest terms add these [annotations to your ingress](http://docs.cert-manager.io/en/latest/reference/ingress-shim.html#supported-annotations) (and update tls-config as well)

```
kubernetes.io/ingress.class: nginx
kubernetes.io/tls-acme: "true"
```

If you want a Let's Encrypt testing certificate (to not expend the cert quota), you can specify another certificate issuer. For a cluster issuer add this:

```
certmanager.k8s.io/cluster-issuer: "letsencrypt-staging"
```

To use a local (for the namespace) issuer use this:

```
certmanager.k8s.io/issuer: "letsencrypt-staging"
```

This works because we have defined a default issuer and protocol when we deployed [Cert Manager](releases/infrastructure/hr-cert-manager.yaml).

### Automaticly create DNS entries (External DNS)
We have implemented External DNS with the Kubernetes cluster and connected it to the Azure DNS Zone. This is done with a Azure AD Service Principal that has rights to only change this DNS Zone.

[External DNS](https://github.com/kubernetes-incubator/external-dns) updates DNS Zone entries with the help of annotations on ingress (or loadbalancer) resoources. To create and update a DNS entry use the following annotation

```
external-dns.alpha.kubernetes.io/hostname: demo.example.com.
```

### Full example using Cert Manager and External DNS
This example manifest uses the techniques in the two previous sections and shows how these works together to automate some tedious tasks.
More info can be found on [HelmRelease](https://github.com/weaveworks/flux/blob/master/site/helm-integration.md), in this example we use a git repository
for the Helm chart, but you could use a Helm repository.

```
---
apiVersion: flux.weave.works/v1beta1
kind: HelmRelease
metadata:
  name: sdp-demo
  namespace: prod
  annotations:
    flux.weave.works/automated: "true"
spec:
  releaseName: sdp-demo
  chart:
    git: ssh://git@github.com/equinor/sdp-flux.git
    ref: master
    path: charts/sdp-demo
  values:
    ingress:
      enabled: true
      annotations:
        kubernetes.io/ingress.class: nginx
        kubernetes.io/tls-acme: "true"
        external-dns.alpha.kubernetes.io/hostname: demo.example.com.
      hosts:
      - demo.example.com
      tls:
      - secretName: demo-tls
        hosts:
        - demo.example.com
```

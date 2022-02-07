[![Build Status](https://travis-ci.com/equinor/sdp-flux.svg?token=yR5pmi3sbtpmzTWwTfNG&branch=master)](https://travis-ci.com/equinor/sdp-flux)

# Equinor SDP-Teams K8s GitOps

This is the repository where we define the manifest to be run in our Kubernetes cluster.  
We use [Flux](https://github.com/weaveworks/flux) as the basis for our GitOps workflow.

## Related Repositories

IaC and Bootstrap - https://github.com/equinor/sdp-omnia

## How it works

In essence we create manifests to be run on the Kubernetes cluster, commit them to this repository and then the Flux controller notices the new commit and applies all the YAML files (can be simplified down to `kubectl apply -f FILENAME`).

We have integrated [Kustomize](https://kustomize.io/) support with Flux. This means that the [/base](/base) folder contains common configuration for all our clusters. Any changes between the clusters (mostly DNS config), are made in "patches" to the base file found in the [/dev](/dev) and [/prod](/prod) folders. Different cluster's Flux operator are subscribed to a specific repo, branch, and kustomize-path-path for an effective GitOps workflow.

Typically we set base equals to the values of prod, and patches in dev are mostly used for overwriting ingresses.

Deleting helm releases is currently not done through Flux.

1) Firstly, remove references of the chart from the Git repo. Remember to update the kustomization.yaml files.
2) Then eiher delete the entire namespace of the helm release you wish to remove `kubectl delete helmrelease xxx -n yyy`

## How we use it

By utilizing Kustomize, we are able to use the same manifests in different clusters, with context aware patches. The biggest benefit of this is that we can use a standard git branch strategy, which involves pushing changes to a _dev_ branch, and merging into a _prod_ branch when it's tested OK in dev. For optimal GitOps workflow! :+1

This simplistic branching model will likely not work in the same way for larger teams, but for our use case it works well. Usually the flow is

- Make changes to dev
- Test
- PR from dev branch to prod branch
- Squash and merge if latest dev commits are messy, or add merge commit if history is somewhat clean
- Rebase dev branch on prod branch to keep commits in sync for optimal overview.

Sometimes you make changes to the dev branch, but are not ready to merge into prod yet, but your team member wants to merge something else in.
In these cases, either move your unready changes to a separate branch, and let the other team member merge dev into prod. Alternatively you can keep the changes, intermix commits to dev with your team member, before making a PR, your team member should now take his changes to a separate branch (which has now been tested through the dev branch), and be ready to merge from the feature branch into prod.

## Naming conventions

The `custom-charts` folder contains the charts we have created ourselves and and is needed for our cluster.  

The creation of new namespaces is done by creating a new file with the same name as the namespace(.yaml) and place it under the folder `namespaces`.

All other k8s manifests are placed in the `base` folder, organized by _namespace_ and service.  
We keep one k8s resource in each file, and name the file the type of k8s resource it is. So an _ingress_ resource for the _demo_ application, in the namespace _apps_ will be named; `./base/apps/demo/ingress.yaml`

## Using SealedSecrets

Sometimes we need to store secrets in the Git repository to make sure our repository is the primary source of truth. In these cases we use a tool called [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets). With this we can store secrets enrypted in the repository and be sure that Flux manages and puts them in the Kubernetes cluster.

Note that some secrets must be in place before deployments such as flux are in place. These are created in the sdp-omnia repo, with secrets stored to Azure Keyvault.

### Install client

- Download [kubeseal](https://github.com/bitnami-labs/sealed-secrets/releases)
- Put `kubeseal-linux-amd64` or `kubeseal-darwin-amd64` in your path and rename it to `kubeseal`.

### First time

After first run we need to export the private and public key. The public key is what we all use to encrypt the secrets and the private key is used by the controller to decrypt the secrets and put them in the cluster. It is important to have a backup of the private key, but _NEVER_ commit that to the repository.

- To get the __private key__ (remember to store this file somewhere safe so we can restore in case of emergency)
  `kubectl get secret -n sealed-secrets sealed-secret-custom-key -o yaml > sealedsecrets.yaml`

- Use the kubeseal tool to get the __public key__
  `kubeseal --controller-namespace infrastructure --controller-name sealed-secrets --fetch-cert > secret.pem`

### Creating SealedSecrets

You need to use the kubectl to initially create the secret and then pipe this to kubeseal to make it encrypted.

``` bash
# From literal
kubectl -n <NAMESPACE> create secret generic <SECRETNAME> --dry-run=client --from-literal=<KEY>=<VALUES> -o json | kubeseal --format yaml --cert sealed-secret.pem > sealed-secret.yaml

# From file
kubectl -n <NAMESPACE> create secret generic <SECRETNAME> --dry-run=client --from-file=<FILENAME> -o json | kubeseal --cert sealed-secret.pem --format yaml > sealed-secret.yaml

# TLS secret
kubectl create secret tls <SECRETNAME> --key myTLSCert.key --cert myTLSCert.crt --dry-run=client -o json | kubeseal --format yaml --cert sealed-secret.pem > sealed-secret-tls.yaml
```

Make sure to place the secrets in the appropriate namespace folder to keep the repository organised.

## Oauth2 Proxy

To utilize oauth2-proxy to authenticate users before they can access a web application, add these lines to the **ingress annotation**:

``` yaml
nginx.ingress.kubernetes.io/auth-url: "https://$host/oauth2/auth"
nginx.ingress.kubernetes.io/auth-signin: "https://$host/oauth2/start?rd=$escaped_request_uri"
```

You also need a **host specific ingress for the proxy**. That could look like [this](examples/oauth2-ingress.yaml).

There is also a few more things to note;

- The oauth2-proxy need to be deployed in the same namespace
- The proxy must be configured with the specific Azure app. This is where we define access. Each proxy can only authenticate *one* application.
- Note that in Helm version < v3, the name of a helm release must be uniq in the *cluster*, NOT within a *namespace*. So to deploy multiple oauth2-proxy instances, the helm release name must be different, the service name will also change.

### Configure Oauth2-proxy

Each oath2 HelmRelease need a secret containing there keys;

- client-id
- client-secret
- cookie-secret

The cookie secret can be created like this;  

```bash
docker run -ti --rm python:3-alpine python -c 'import secrets,base64; print(base64.b64encode(base64.b64encode(secrets.token_bytes(16))));'`
```

You only need to copy the content after "b'".

## Tips and tricks

How to do something we do a lot? If you know, type them up here and we shall all be the wiser for it.

### Using a Private Container Registry

We assume the ACR has been created and set up in the bootstrapping portion of the Kubernetes cluster. Take a look in sdp-aks repository for information on how to create and set up a new ACR. To use the ACR we need a service principal that should have been created by ARM templates.

- Start by creating the secret which stores docker registry information;  
  `kubectl -n <NAMESPACE> create secret docker-registry <SECRET_NAME> --docker-server=<REGISTRY_URL> --docker-username=<SERVICE_PRINCIPAL_ID> --docker-password=<SERVICE_PRINCIPAL_PASSWORD> --docker-email=gm_sds_rdi@equinor.com`

- To use this secret in the image pull, use it in a manifest like so;

```yaml
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

### Produce certificates from ingress config (Cert Manager)

We use [CertManager](https://github.com/jetstack/cert-manager) for creating, validating and deploying Let'sEncrypt certificates. CertManager can shortcut the usual procedure of creating a Certificate resource and then referencing the secret from this Certificate in the ingress by adding a few annotations to the ingress.

In the shortest terms, add these [annotations to your ingress](http://docs.cert-manager.io/en/latest/reference/ingress-shim.html#supported-annotations)

```yaml
kubernetes.io/ingress.class: nginx
kubernetes.io/tls-acme: "true"
```

If you want a Let'sEncrypt testing certificate (to not expend the cert quota), you can specify another certificate issuer. For a cluster issuer add this:

```yaml
certmanager.k8s.io/cluster-issuer: "letsencrypt-staging"
```

This works because we have defined a default issuer and protocol when we deployed [CertManager](releases/infrastructure/hr-cert-manager.yaml).

### Automaticly create DNS entries (External DNS)

We have implemented External DNS with the Kubernetes cluster and connected it to the Azure DNS Zone. This is done with a Azure AD Service Principal that has rights to only change this DNS Zone.

[External DNS](https://github.com/kubernetes-incubator/external-dns) updates DNS Zone entries with the help of annotations in ingress resources. To create and update a DNS entry use the following annotation

```yaml
external-dns.alpha.kubernetes.io/hostname: demo.example.com.
```

### Full example using Cert Manager and External DNS

This example manifest uses the techniques in the two previous sections and shows how these works together to automate some tedious tasks.
More info can be found on [HelmRelease](https://github.com/weaveworks/flux/blob/master/site/helm-integration.md), in this example we use a git repository
for the Helm chart, but you could use a Helm repository.

```yaml
---
apiVersion: helm.fluxcd.io/v1 
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
    ref: prod
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

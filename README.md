# Repository used for Kubernetes GitOps
This is the repository where we define the manifest to be run in Kubernetes. We use [Flux](https://github.com/weaveworks/flux) as the basis for our GitOps workflow.

## How it works
In essence we create manifests to be run on the Kubernetes cluster, commit them to this repository and then the Flux controller notices the new commit and applies all the YAML files (can be simplified down to `kubectl apply -f FILENAME`).

## How we use it
In production we never commit straight to the repository, always create a new branch (or use your existing) (`git branch -b new_branch_name`) modify what you want changed or implement your new feature, commit (`git add . && git commit -m 'commit message'`) and then push to remote (`git push -u origin new_branch_name`). After all this editing, commit and pushing you need to create a pull-request so that you, but preferably another on your team can see review the changes and merge the files.

__TODO__: Find a procedure for testing the code before commiting and running on prod.

## Naming conventions
We use the chart folder for Helm charts (with the Flux version we have been using we need to download and the Helm charts to this repo), the namespaces folder is used strictly for creating new namespaces and can be seen as a reference for what namespaces is in use. The releases folder holds all our deployed manifests. Under releases we structure the manifests in their respective folders named after the namespace which they reside.

For the manifest we have this naming structure _prefix-application-name.yaml_. Descriptive names is key so that the rest of the team knows at first glance what the manifest does. Prefix is the manifest kind noted in short hand if apropriate, e.g. issuer, clusterissuer (cissuer for short), ingress (ing), helmrelease (hr).

__TODO__: Do we need a list of shorthands? Or is this clear enough?

## Using Sealed Secrets
Sometimes we need to store secrets in the Git repository to make sure our repository is the primary source of truth. In these cases we use a system called [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets). With this system we can store secrets enrypted in the repository and be sure that Flux manages and puts them in the Kubernetes cluster

### Install client

- Download [kubeseal](https://github.com/bitnami-labs/sealed-secrets/releases)
- Put `kubeseal-linux-amd64` or `kubeseal-darwin-amd64` in your path

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
kubectl -n NAMESPACE create secret generic SECRETNAME --dry-run --from-literal=KEY=VALUES -o json | kubeseal --format=yaml --cert secret.pem > SECRETNAME.yaml

# To use from file
kubectl -n NAMESPACE create secret generic SECRETNAME --dry-run --from-file=FILENAME -o json | kubeseal --format=yaml --cert secret.pem > SECRETNAME.yaml
```
Make sure to place the secrets in the appropriate namespace folder to keep the repository organised.

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
    git: ssh://git@github.com/Statoil/sdp-flux.git
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

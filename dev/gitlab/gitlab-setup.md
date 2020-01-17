# Setup of Gitlab helm chart
Currently we have resolved some issues using manual steps. In order to remember these we will document them here until a more GitOps-friendly method works.

## Minio region

At first we thought setting the minio region in secrets to "North Europe" would be correct, but it appears that the setting should be us-east-1 (AWS default)

## HTTP 500 for admin pages

__This step might remove access to existing repos, beware__

Editing any setting in the admin area resulted in http 500
Solution: `kubectl exec -it <task-runner-pod-name> /srv/gitlab/bin/rails console`

[And follow these steps](https://gitlab.com/gitlab-org/gitlab-ce/issues/56403#note_136382583)

There have been some occurences where running the above step still give http 500 on the /admin/runners page. In test environments you can delete the contents of the table. `DELETE FROM ci_runners;`, and you should get access. __BE careful__ attempting this in production environments without backups of both kubernetes secrets and the Postgres database.

## Unable to register Gitlab runners

Some token issues with gitlab runners failing to register with Gitlab.
Solution: 

Reset token. Find new token from [/admin/runners page](https://gitlab.dev.sdpaks.equinor.com/admin/runners)
Create new "gitlab-gitlab-runner-secret" containing the token:
`kubectl create secret generic gitlab-gitlab-runner-secret --from-literal=runner-registration-token=<new-token> --from-literal=runner-token=""`


### Gitlab runners not supported on IPV6
IPV6 is not supported by our aks-network for some reason
Set these settings:

https://gitlab.com/gitlab-org/gitlab-runner/issues/4131

```envVars:
    global:
      runner:
        envVars:
          - name: LISTEN_ADDRESS
            value: :9252
```

### gitlab secret resetting

Before we have a permanent token, you may experience that the gitlab-rails-secret resets.

Create a file looking like this:

```
production:
  secret_key_base: xxxxxx...
  db_key_base: xxxxxx...
  otp_key_base: xxxxxx...
  openid_connect_signing_key: |
    -----BEGIN RSA PRIVATE KEY-----
    xxxx-.....

```

`k create secret generic gitlab-rails-secret -n gitlab --from-file="C:\secrets.yaml"`

If lost, It can be found in the `/etc/gitlab/gitlab-secrets.json` file in the Omnibus container on-prem.
You may face http 500 when accessing /admin pages if this key is not set correctly.


## Migrate and Restore

First ensure that your gitlab-rails-secret in AKS has the important lines from  `/etc/gitlab/gitlab-secrets.json` file in the Omnibus container on-prem.

Next, follow this:

https://docs.gitlab.com/charts/installation/migration/

stop after you have successfully completed `gitlab-rake gitlab:backup:create`

- kubectl exec into your gitlab task runner in AKS.
- Run the command `gitlab-rake cache:clear`

And then follow this guide

https://docs.gitlab.com/charts/backup-restore/restore.html

You will probably also have to reset the runner registration token as described in your guide.
Verify that you can git clone, runners work etc.

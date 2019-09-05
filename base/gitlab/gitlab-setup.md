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


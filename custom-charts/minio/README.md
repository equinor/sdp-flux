Needed because this is the only way to set --compat  flag which is currently (december 2019) required for gitlab to reach minio
change all occurences i deployment.yaml from "/usr/bin/docker-entrypoint.sh minio" to "/usr/bin/docker-entrypoint.sh minio --compat"
https://github.com/helm/charts/issues/17075
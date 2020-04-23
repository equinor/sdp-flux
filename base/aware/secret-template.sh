#! /usr/bin/bash
# Get API Key like this;
#sensuctl configure -n --username "MyUSERNAME" --password "MyPassword" --namespace "default" --url "https://sensu-api.sdpaks.equinor.com:443"

#sensuctl api-key grant admin
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: aware-sensu-key
  namespace: aware
type: Opaque
data:
  SENSU_KEY: $(echo -n $"MY_API_KEY" | base64 -w0)
EOF

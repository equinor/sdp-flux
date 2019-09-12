Pre-reqs installed this way

helm install --namespace rook-ceph rook-master/rook-ceph --set agent.flexVolumeDirPath="/var/lib/kubelet/volumeplugins" --name rook-ceph --version v1.1.0-beta.0.77.gff73043
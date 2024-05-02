
clusterName=otus-cluster
## the Namespace and ServiceAccount name that is used for the config
serviceAccount=$1
namespace="$2"

## New Kubeconfig file name
newfile=otus.kubeconfig

######################
#  Main Script       #
#                    #
######################

server=$(kubectl config view --minify --raw -o jsonpath='{.clusters[].cluster.server}' | sed 's/"//')
secretName=$(kubectl -n $namespace get secret | grep $serviceAccount | awk '{print $1}')
ca=$(kubectl --namespace $namespace get secret/$secretName -o jsonpath='{.data.ca\.crt}')
token=$(kubectl --namespace $namespace get secret/$secretName -o jsonpath='{.data.token}' | base64 --decode)

echo "
---
apiVersion: v1
kind: Config
clusters:
  - name: ${clusterName}
    cluster:
      certificate-authority-data: ${ca}
      server: ${server}
contexts:
  - name: ${serviceAccount}@${clusterName}
    context:
      cluster: ${clusterName}
      namespace: ${namespace}
      user: ${serviceAccount}
users:
  - name: ${serviceAccount}
    user:
      token: ${token}
current-context: ${serviceAccount}@${clusterName}
" >> ${newfile}.yaml
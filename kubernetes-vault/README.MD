# HashiCorp Vault Lab

Основные манифесты конфигурационные файлы по 11-му дз.


# Подготовка
Установка Consul, Vault в HA конфигурации, unsealing хранилища. Подготовка vault к работе.

    cd kubernetes-vault/
    helm upgrade --install consul consul-k8s/charts/consul/ --set global.name=consul -f ./values_consul.yaml --create-namespace -n consul
    kubectl get pods -n consul
    
    helm upgrade --install vault vault-helm/ -f ./values_vault.yaml --create-namespace -n vault
    kubectl get pods -n vault
    
    kubectl -n vault exec -it vault-0 -- vault operator init
    unseal1=<xxx>
    unseal2=<xxx>
    unseal3=<xxx>
    root_token=<xxx>
    
    kubectl -n vault exec -it vault-0 -- vault operator unseal $unseal1
    kubectl -n vault exec -it vault-0 -- vault operator unseal $unseal2
    kubectl -n vault exec -it vault-0 -- vault operator unseal $unseal3
    kubectl -n vault exec -it vault-1 -- vault operator unseal $unseal1
    kubectl -n vault exec -it vault-1 -- vault operator unseal $unseal2
    kubectl -n vault exec -it vault-1 -- vault operator unseal $unseal3
    kubectl -n vault exec -it vault-2 -- vault operator unseal $unseal1
    kubectl -n vault exec -it vault-2 -- vault operator unseal $unseal2
    kubectl -n vault exec -it vault-2 -- vault operator unseal $unseal3
    
    kubectl -n vault exec -it vault-0 -- vault login $root_token

    kubectl -n vault exec -it vault-0 -- vault secrets enable -version=1 -path=otus kv
    kubectl -n vault exec -it vault-0 -- vault kv put otus/cred username='otus' password='asajkjkahs'
    kubectl -n vault exec -it vault-0 -- vault kv get otus/cred

Создание SA, CRB, Secret

    kubectl apply -f sa.yaml

Подготовка движка kubernetes, создание role, политик доступа к секретам

    kubectl -n vault exec -it vault-0 -- vault auth enable kubernetes
    
    JWT=$(kubectl get secret vault-auth-token -n vault -o go-template='{{ .data.token }}' | base64 --decode)
    KUBE_HOST=$(kubectl config view --raw --minify --flatten --output='jsonpath={.clusters[].cluster.server}')
    KUBE_CA_CERT=$(kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[].cluster.certificate-authority-data}' | base64 --decode)
    
    kubectl -n vault exec -it vault-0 -- vault write auth/kubernetes/config token_reviewer_jwt="$JWT" kubernetes_host="$KUBE_HOST" kubernetes_ca_cert="$KUBE_CA_CERT" disable_local_ca_jwt="true"
    
    kubectl -n vault exec -it vault-0 -- vault write auth/kubernetes/role/otus bound_service_account_names=vault-auth bound_service_account_namespaces=vault policies=otus-policy ttl=72h
    
    cat otus_policy.hcl | kubectl -n vault exec -it vault-0 -- vault policy write otus-policy -

Устанавливаем External Secrets из чарта, создаем конфигурацию

    helm repo add external-secrets https://charts.external-secrets.io
    helm upgrade --install external-secrets external-secrets/external-secrets --create-namespace -n vault

    kubectl apply -f secretstore.yaml
    kubectl apply -f externalsecret.yaml

проверяем, что нет ошибок и происходит вычитка секрета из vault

    kubectl describe es -n vault
    kubectl -n vault get secret/otus-cred
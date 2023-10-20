## Installing kind
If you are using [`asdf`](https://asdf-vm.com/) you can install the exact version of Kind used in this project.

```
asdf plugin-add kind https://github.com/reegnz/asdf-kind.git
asdf install
```

If you prefer to install another way, take a look at the `.tool-versions` file to see the version of Kind used in these instructions.

## Kind Cluster creation commands

1. Simple single node creation command
   ```bash
   # Default cluster context name is `kind`
   kind create cluster
   ```
   or
   ```bash
   # Cluster with context name as `kind-2`
   kind create cluster --name kind-2 
   ```
2. Three node creation command using a Kind `config.yaml` file
   ```bash
   kind create cluster --config kind/3node-config.yaml
   ```

## Installing NGINX Plus Ingress Controller

1. Clone the NGINX Ingress Controller repository and change into the deployments folder
   ```bash
   git clone https://github.com/nginxinc/kubernetes-ingress.git --branch v3.3.1
   cd kubernetes-ingress/deployments
   ```

2. Create a namespace and a service account for NIC
   ```bash
   kubectl apply -f common/ns-and-sa.yaml
   ```
3. Create a cluster role and cluster role binding for the service account
   ```bash
   kubectl apply -f rbac/rbac.yaml
   ```
4. Create a secret with a TLS certificate and a key for the default server in NGINX 
   ```bash
   kubectl apply -f ../examples/shared-examples/default-server-secret/default-server-secret.yaml
   ```
5. Create a config map for customizing NGINX configuration
   ```bash
   kubectl apply -f common/nginx-config.yaml
   ```
6. Create custom resource definitions for VirtualServer and VirtualServerRoute, TransportServer, Policy and GlobalConfiguration resources
   ```bash
   kubectl apply -f common/crds/k8s.nginx.org_virtualservers.yaml
   kubectl apply -f common/crds/k8s.nginx.org_virtualserverroutes.yaml
   kubectl apply -f common/crds/k8s.nginx.org_transportservers.yaml
   kubectl apply -f common/crds/k8s.nginx.org_policies.yaml
   kubectl apply -f common/crds/k8s.nginx.org_globalconfigurations.yaml
   ```
7. Create an IngressClass resource
   ```bash
   cd ../../nic
   kubectl apply -f install/ingress-class.yaml
   ```
8. Export NGINX Plus JWT token into a shell variable.
   ```bash
   export jwt_token=$(cat install/nginx-repo.jwt)
   ```
9. Confirm that the `jwt_token` has been set by running below command.
    ```bash
    echo $jwt_token
    ```
10. Create a Kubernetes docker-registry secret type on the cluster, by passing the `jwt_token` shell variable as the username and `none` for password (Password is unused). The name of the docker server is `private-registry.nginx.com`.
    ```bash
    kubectl create secret docker-registry regcred --docker-server=private-registry.nginx.com --docker-username=$jwt_token --docker-password=none -n nginx-ingress
    ```
11. Deploy NGINX Ingress Controller as a Deployment using the updated manifest file
    ```bash
    kubectl apply -f install/nginx-plus-ingress.yaml
    ```

   
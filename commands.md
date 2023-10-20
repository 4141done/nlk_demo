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

## Install the cafe App
1. Check the `nginx-loadbalancer-kubernetes` project.  From the root of the project: `git clone https://github.com/nginxinc/nginx-loadbalancer-kubernetes.git`

2. Go to `./nginx-loadbalancer-kubernetes/docs/cafe-demo`
3. Deploy the application using the following three commands:
      ```bash
      kubectl apply -f cafe-secret.yaml
      kubectl apply -f cafe.yaml
      kubectl apply -f cafe-virtualserver.yaml
      ```

## Installing NGINX Plus as a Load Balancer
1. Make sure you have the `nginx-repo.crt` and `nginx-repo.key` files from myf5. Place them in `./nginx-plus/ssl/nginx`

2. From the root of the project, run `docker compose up`

3. Test the installation by going to `http://localhost:8080` in your browser.  You should see the NGINX Plus dashboard

## Install the `ngnix-loadbalancer-kubernetes` Controller
1. Get the ip address of the nginx plus container in the `kind` network:
      ```bash
      export PLUS_IP=$(docker network inspect kind | grep -o '"Name": "nginx-plus"' -A 5 | grep '"IPv4Address":' | cut -d '"' -f 4 | sed 's/\/16//')
      ```
      Thanks ChatGPT

1. Modify the configmap `sed -i "" "s/PLUS_IP/$PLUS_IP/g" ./nlk/config-map.yaml` (Thanks ChatGPT)

2. From the `./nginx-loadbalancer-kubernetes` directory, run the following commands in order to install the controller:
      ```bash
      kubectl apply -f deployments/deployment/namespace.yaml
      ./deployments/rbac/apply.sh
      kubectl apply -f deployments/deployment/configmap.yaml
      kubectl apply -f deployments/deployment/deployment.yaml
      ```
3. Check the logs to be sure it's running:
      ```bash
      kubectl -n nlk get pods | grep deployment | cut -f1 -d" "  | xargs kubectl logs -n nlk --follow $1
      ```

## Configuring `nginx-loadbalancer-kubernetes` Upstreams
We need to configure the NGINX Plus load balancer with certain upstreams, then provide the names of those upstreams to NLK so that it knows which ones to manage.

1. Add an entry in your `/etc/hosts` file that looks like this:
`PLUS_IP cafe.example.com`
where `PLUS_IP` is equal to the output of
      ```bash
      docker network inspect kind | grep -o '"Name": "nginx-plus"' -A 5 | grep '"IPv4Address":' | cut -d '"' -f 4 | sed 's/\/16//'
      ```

### Add the loadbalancer Manifest
1. Modify the loadbalancer manifest `sed -i "" "s/PLUS_IP/$PLUS_IP/g" ./nlk/loadbalancer.yaml` (Thanks ChatGPT)

1. Apply it: `kubectl apply -f ./nlk/loadbalancer.yaml`

## Questions
* Do we use service type loadbalancer or nodeport?
* In the loadbalancer manifest, what does `nginxinc.io/XXX: "http"` do?
* How does NLK make the LoadBalancer service type?

   
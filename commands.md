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
   ```
   ```bash
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
1. Check the `nginx-loadbalancer-kubernetes` project.  From the root of the project perform a git clone: 
   ```bash
   cd ..
   git clone https://github.com/nginxinc/nginx-loadbalancer-kubernetes.git
   ```

2. Navigate to the cafe-demo directory
   ```bash
   cd nginx-loadbalancer-kubernetes/docs/cafe-demo
   ```
3. Deploy the application using the following three commands:
   ```bash
   kubectl apply -f cafe-secret.yaml
   kubectl apply -f cafe.yaml
   kubectl apply -f cafe-virtualserver.yaml
   cd ../../..
   ```
   >**Note:** Instead of using `Ingress` type resource we are making use of `virtualserver` resource that handles routing.

## Installing NGINX Plus as a Load Balancer
1. Make sure you have the `nginx-repo.crt` and `nginx-repo.key` files from myf5. Place them in `./nginx-plus/etc/ssl/nginx`
   ```bash
   ls nginx-plus/etc/ssl/nginx
   ```

2. From the root of the project, run below command      
   ```bash
   docker compose up
   ```

3. Test the installation by going to http://localhost:9000/dashboard.html in your browser.  You should see the NGINX Plus dashboard

## Install the `ngnix-loadbalancer-kubernetes` Controller
1. Get the ip address of the nginx plus container in the `kind` network:
      ```bash
      export PLUS_IP=$(docker network inspect kind | grep -o '"Name": "nginx-plus"' -A 5 | grep '"IPv4Address":' | cut -d '"' -f 4 | sed 's/\/16//')
      ```
      (Thanks ChatGPT)

2. Modify the configmap 
   ```bash
   sed -i "" "s/PLUS_IP/$PLUS_IP/g" ./nlk/config-map.yaml
   ``` 
   (Thanks ChatGPT)

3. Run the following commands in order to install the controller:
   ```bash
   kubectl apply -f ./nginx-loadbalancer-kubernetes/deployments/deployment/namespace.yaml
   ./nginx-loadbalancer-kubernetes/deployments/rbac/apply.sh
   kubectl apply -f ./nlk/config-map.yaml
   kubectl apply -f ./nginx-loadbalancer-kubernetes/deployments/deployment/deployment.yaml
   ```


4. Check the logs to be sure it's running:
   ```bash
   kubectl -n nlk get pods | grep deployment | cut -f1 -d" "  | xargs kubectl logs -n nlk --follow $1
   ```
   ```bash
   ###Sample Output###
   time="2023-10-25T16:05:50Z" level=info msg="Settings::Initialize"
   time="2023-10-25T16:05:50Z" level=info msg="Watcher::buildEventHandlerForAdd"
   time="2023-10-25T16:05:50Z" level=info msg="Watcher::buildEventHandlerForDelete"
   time="2023-10-25T16:05:50Z" level=info msg="Watcher::buildEventHandlerForUpdate"
   time="2023-10-25T16:05:50Z" level=info msg="Started probe listener on:51031"
   I1025 16:05:50.603318       1 shared_informer.go:273] Waiting for caches to sync for nlk-handler
   time="2023-10-25T16:05:50Z" level=error msg="Settings::handleUpdateEvent: nginx-hosts key not found in ConfigMap"
   I1025 16:05:50.703922       1 shared_informer.go:280] Caches are synced for nlk-handler
   ```

## Configuring `nginx-loadbalancer-kubernetes` Upstreams
We need to configure the NGINX Plus load balancer with certain upstreams, then provide the names of those upstreams to NLK so that it knows which ones to manage.

1. Add an entry in your `/etc/hosts` file that looks like this:
      `127.0.0.1 cafe.example.com`
      This works because the NGINX Plus container is started with port bindings to `localhost`

### Add the `NodePort` Manifest
1. Run the below command to deploy the nodeport service.
   ```bash
   kubectl apply -f ./nlk/nodeport.yaml
   ```

## Testing
1. Check the NGINX Plus dashboards to make sure that you have three upstreams (http://localhost:9000/dashboard.html#upstreams). They should all be "green" and have a high port number
2. Try some `curl` request as shown below 
   ```bash
   curl -H -i -k https://cafe.example.com/tea
   ``` 
   or 
   ```bash
   curl -H -i -k https://cafe.example.com/coffee
   ```
### Sending Traffic with `wrk`
Here is the basic command

```bash
docker run --rm --network kind elswork/wrk -t4 -c200 -d15m -H 'Host: cafe.example.com' --timeout 2s https://nginx-plus/coffee
```
`-d` is duration, `-t` is number of threads, `-c` is number of connections to keep open.

`-c` and `-t` relate as such:
```
total number of HTTP connections to keep open with
                   each thread handling N = connections/threads
```

## Visualization
### Prometheus
The prometheus dashboard is available at `localhost:9090`.  You can look for specific metrics like `nginxplus_location_zone_responses` to test if it is working.  Click the "world" icon next to the "execute" button to explore metrics.  Sick.

#### Prometheus Operator for Kubernetes
`LATEST=$(curl -s https://api.github.com/repos/prometheus-operator/prometheus-operator/releases/latest | jq -cr .tag_name)`

`curl -sL https://github.com/prometheus-operator/prometheus-operator/releases/download/${LATEST}/bundle.yaml | kubectl create -f -`

Validate installed 
```bash
kubectl wait --for=condition=Ready pods -l  app.kubernetes.io/name=prometheus-operator -n default
```

Apply the manifests:
`kubectl apply -f prometheus/service-account.yaml`
`kubectl apply -f prometheus/deployment.yaml`


Expose the Prometheus endpoint outside the cluster.  To `nginx-loadbalancer-kubernetes/docs/cafe-demo/cafe-virtualserver.yaml`
add this upstream:
```yaml
  - name: prometheus
    service: prometheus-main
    port: 9090
    lb-method: round_robin
    slow-start: 20s
```
Then under `routes` add the following paths:
```yaml
  - path: /metrics
    action:
      pass: prometheus
  - path: /federate
    action:
      pass: prometheus
```


### Grafana
Grafana will be running at `localhost:3000`.  There are currently a few manual steps to get it running:

1. Go to `http://localhost:3000/connections/add-new-connection` and add a new "prometheus" type connection.  The only thing you have to configure is the "prometheus server url" which should be set to `http://prometheus-external:9090`

2. Copy the uuid from the address bar (it will look something like `dfc89e77-4bdb-4d50-a2f1-faf1c9b63fda`).  In `./grafana/grafana-dashboard.json` replace the `uid` field under all datasources with that uuid.

## NAP Demo

1. To show NAP related security blocking, modify the `docker-compose.yml` file to make use of `Dockerfile_NAP` instead of `Dockerfile_NonNAP` to create `nginx-plus` service.
   ```yaml
   ...
   services:
   # NGINX Plus Load Balancer
   nginx-plus:
         container_name: nginx-plus
         hostname: nginx-plus
         build: 
            context: nginx-plus
            dockerfile: Dockerfile_NonNAP
   ...
   ```
   should be replaced with 
   ```yaml
   ...
   services:
   # NGINX Plus Load Balancer
   nginx-plus:
         container_name: nginx-plus
         hostname: nginx-plus
         build: 
            context: nginx-plus
            dockerfile: Dockerfile_NAP
   ...
   ```
2. Within `nginx-plus/etc/nginx` directory rename the `nginx.conf` file to `nginx.conf.nonnap` and rename the `nginx.conf.nap` file to `nginx.conf`.
3. Run docker compose up command.

## Questions
* Do we use service type loadbalancer or nodeport? Use Nodeport
* In the loadbalancer manifest, what does `nginxinc.io/XXX: "http"` do? It tells NLK whether to communicate the ips to the layer 4 api or the layer 7 api
* How does NLK make the LoadBalancer service type? it doesn't! Not sure why it uses loadbalancer in the example.


## Teardown
```bash
kind delete cluster --name nlk-multi-node-demo
docker compose down
```
   
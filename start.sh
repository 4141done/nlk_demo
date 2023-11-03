#! /bin/bash
echo "Cleaning up any old components..."
echo "💀 Taking down docker compose"
docker compose down
echo "💀 Ensuring cluster is down"
kind delete cluster --name nlk-multi-node-demo

echo "Standing up cluster and external elements..."
echo "🌺🐥🌺 Standing up external docker containers"
docker compose up -d

echo "🌺🐥🌺 Creating Kind cluster"
kind create cluster --config kind/3node-config.yaml
sleep 10
kubectl cluster-info --context kind-nlk-multi-node-demo

echo "💖💖 Done standing up cluster 💖💖"

## Make sure the config-map.yaml is the expected value for templating
cat <<EOF > nlk/config-map.yaml
apiVersion: v1
kind: ConfigMap
data:
  nginx-hosts:
     "http://PLUS_IP:9000/api"
metadata:
  name: nlk-config
  namespace: nlk

EOF


## Make sure the loadbalancer.yaml is the expected value for templating
cat <<EOF > nlk/loadbalancer.yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-ingress
  namespace: nginx-ingress
  annotations:
    nginxinc.io/nlk-cafe: "http"   # Must be added
spec:
  type: LoadBalancer
  externalIPs:
  - PLUS_IP 
  ports:
  - port: 443
    targetPort: 443
    protocol: TCP
    name: nlk-cafe     # Must match Nginx upstream name
  selector:
    app: nginx-ingress

EOF

echo "🈁 Installing ingress controller..."
kubectl apply -f kubernetes-ingress/deployments/common/ns-and-sa.yaml
kubectl apply -f kubernetes-ingress/deployments/rbac/rbac.yaml
kubectl apply -f kubernetes-ingress/examples/shared-examples/default-server-secret/default-server-secret.yaml
kubectl apply -f kubernetes-ingress/deployments/common/nginx-config.yaml
kubectl apply -f kubernetes-ingress/deployments/common/crds/k8s.nginx.org_virtualservers.yaml
kubectl apply -f kubernetes-ingress/deployments/common/crds/k8s.nginx.org_virtualserverroutes.yaml
kubectl apply -f kubernetes-ingress/deployments/common/crds/k8s.nginx.org_transportservers.yaml
kubectl apply -f kubernetes-ingress/deployments/common/crds/k8s.nginx.org_policies.yaml
kubectl apply -f kubernetes-ingress/deployments/common/crds/k8s.nginx.org_globalconfigurations.yaml


kubectl apply -f nic/install/ingress-class.yaml
export jwt_token=$(cat nic/install/nginx-repo.jwt)
echo $jwt_token
kubectl create secret docker-registry regcred --docker-server=private-registry.nginx.com --docker-username=$jwt_token --docker-password=none -n nginx-ingress
kubectl apply -f nic/install/nginx-plus-ingress.yaml

echo "☕🍵 Installing cafe app..."
kubectl apply -f nginx-loadbalancer-kubernetes/docs/cafe-demo/cafe-secret.yaml
kubectl apply -f nginx-loadbalancer-kubernetes/docs/cafe-demo/cafe.yaml
kubectl apply -f nginx-loadbalancer-kubernetes/docs/cafe-demo/cafe-virtualserver.yaml


echo "🐸 Installing NLK"
export PLUS_IP=$(docker network inspect kind | grep -o '"Name": "nginx-plus"' -A 5 | grep '"IPv4Address":' | cut -d '"' -f 4 | sed 's/\/16//')
sed -i "" "s/PLUS_IP/$PLUS_IP/g" ./nlk/config-map.yaml
sed -i "" "s/PLUS_IP/$PLUS_IP/g" ./nlk/loadbalancer.yaml

echo "PLUS_IP is $PLUS_IP"

kubectl apply -f nginx-loadbalancer-kubernetes/deployments/deployment/namespace.yaml
./nginx-loadbalancer-kubernetes/deployments/rbac/apply.sh
kubectl apply -f nlk/config-map.yaml
kubectl apply -f nginx-loadbalancer-kubernetes/deployments/deployment/deployment.yaml

echo "⚓ Adding NodePort"
sleep 10
kubectl apply -f nlk/nodeport.yaml

# echo "Adding Loadbalancer service"
# sleep 10
# kubectl apply -f nlk/loadbalancer.yaml

echo "🐳🐳 Done! 🐳🐳"
printf "Next steps:\n    1. Check the NGINX Plus Dashboard at http://localhost:9000/dashboard\n    2. Make sure your /etc/hosts has the entry '127.0.0.1 cafe.example.com'\n    3. Try to hit the services 'curl -H -i -k https://cafe.example.com/tea'"

#! /bin/bash

echo "Remember to run the following before running this script.  If you forgot, press ^c and do it now..."
echo "kind create cluster --config kind/3node-config.yaml"
echo "docker compose up"

sleep 10

echo "Sounds like you are ready, setting up..."

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

echo "installing ingress controller..."
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
kubectl apply -f install/nginx-plus-ingress.yaml

echo "Installing cafe app..."
kubectl apply -f nginx-loadbalancer-kubernetes/docs/cafe-demo/cafe-secret.yaml
kubectl apply -f nginx-loadbalancer-kubernetes/docs/cafe-demo/cafe.yaml
kubectl apply -f nginx-loadbalancer-kubernetes/docs/cafe-demo/cafe-virtualserver.yaml


echo "Installing NLK"
export PLUS_IP=$(docker network inspect kind | grep -o '"Name": "nginx-plus"' -A 5 | grep '"IPv4Address":' | cut -d '"' -f 4 | sed 's/\/16//')
sed -i "" "s/PLUS_IP/$PLUS_IP/g" ./nlk/config-map.yaml


kubectl apply -f nginx-loadbalancer-kubernetes/deployments/deployment/namespace.yaml
./nginx-loadbalancer-kubernetes/deployments/rbac/apply.sh
kubectl apply -f nlk/config-map.yaml
kubectl apply -f nginx-loadbalancer-kubernetes/deployments/deployment/deployment.yaml


echo "Adding NodePort"

echo "Done!"
echo "Next steps:\n    1. Check the NGINX Plus Dashboard at http://localhost:9000/dashboard\n    2. Make sure your /etc/hosts has the entry '127.0.0.1 cafe.example.com'\n    3. Try to hit the services 'curl -H -i -k https://cafe.example.com/tea'"
kubectl apply -f nlk/nodeport.yaml
# mtls investigation

Deploy the operators, control plane, and bookinfo app

```sh
./install-service-mesh-operators.sh

source default-vars.txt && export $(cut -d= -f1 default-vars.txt)

./install-service-mesh-control-plane.sh

./install-basic-gateway-configuration.sh
```

Deploy a mesh-external application

```sh
oc new-project mesh-external

oc new-app centos/nginx-112-centos7~https://github.com/sclorg/nginx-ex -n mesh-external
```

Test connectivity to mesh-external service from bookinfo ratings container is OK

```sh
oc rsh -n bookinfo -c ratings deployment/ratings-v1
curl -I http://nginx-ex.mesh-external.svc:8080
exit
```

Add the mesh-external namespace as a member of the mesh (no istio-proxy sidecar on applicaiton)

```sh
cat << EOF | oc apply -f -
apiVersion: maistra.io/v1
kind: ServiceMeshMember
metadata:
  name: default
  namespace: mesh-external
spec:
  controlPlaneRef:
    name: basic-install
    namespace: istio-system
EOF
```

Test connectivity to mesh-external service from bookinfo ratings container is 503 Service Unavailable due to mtls

```sh
oc rsh -n bookinfo -c ratings deployment/ratings-v1
curl -I http://nginx-ex.mesh-external.svc:8080
exit
```

Should the connectivity between a pod in a mesh with global mtls enabled and a pod outside of the mesh but in a member namespace work?

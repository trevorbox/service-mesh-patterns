# Service Mesh Patterns

This project provides examples for widely practiced Service Mesh configurations.

> To update the service-mesh submodule to latest commit use `git submodule foreach git pull origin master`

## Setup

### Install service mesh operators

> Note: you need to manually approve the InstallPlans as the script describes.

```sh
./install-service-mesh-operators.sh
```

### Export Default vars

```sh
source default-vars.txt && export $(cut -d= -f1 default-vars.txt)
```

*Or*, Export Custom vars

```sh
export deploy_namespace=bookinfo
export control_plane_namespace=istio-system
export control_plane_name=basic-install
export control_plane_route_name=api
```

## Basic Gateway Configuration

This example demonstrates a basic confiuration using:

- A single Gateway deployed in the *"<control_plane_namespace>"*.
- A VirtualService deployed in the member namespace referencing the Gateway in *"<control_plane_namespace>/<gateway_name>"*.

### Install control plane

```sh
./install-service-mesh-control-plane.sh
```

### Install basic gateway configuration

```sh
./install-basic-gateway-configuration.sh
```

Test the bookinfo application

```sh
# Open the following url in a web browser
echo "https://$(oc get route ${control_plane_route_name} -n ${control_plane_namespace} -o jsonpath={'.spec.host'})/productpage"
```

### Cleanup basic gateway configuration

```sh
./cleanup-basic-gateway-configuration.sh
```

### Cleanup control plane

```sh
./cleanup-service-mesh-control-plane.sh
```

## Multiple Ingress Gateways with MongoDB

This example shows how to deploy MongoDB behind Service Mesh on Openshift and open a NodePort on the mongo ingress gateway for external communication. With this configuration we can present a certificate in the mongo-ingressgateway proxy and test TLS connections from outside the mesh to MongoDB. A normal Openshift route does not support the mongo protocol.

### Install the Service Mesh

Follow the README.md within the service-mesh folder to deploy the control-plane-mongodb

### Install mongodb app

```sh
export deploy_namespace=mongodb

oc new-project ${deploy_namespace}

helm install mongodb -n ${deploy_namespace} mongodb/
```

### Install Mongo Gateway Configuration

> TODO: refactor bookinfo + mongo into the same chart since there is a new reviews-v2 deployment and other dependencies

```sh
export deploy_namespace=mongodb

helm install mongo-gateway-configuration -n ${deploy_namespace} mongo-gateway-configuration/
```

Test normal connectivity to LoadBalancer

```sh
./scripts/ingress-mongodb-setup.sh
```

Test TLS connectivity to LoadBalancer

```sh
./scripts/ingress-mongodb-setup-tls.sh
```

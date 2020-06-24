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

### Test the bookinfo application

Open the following url in a web browser.

```sh
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

The bookinfo application is also deployed with an additional ratings-v2 service that connects to MongoDB via a ServiceEntry with TLS.

### Install control plane mongodb

```sh
./install-service-mesh-control-plane-mongodb.sh
```

### Install mongo gateway configuration

```sh
./install-mongo-gateway-configuration.sh
```

### Setup mongodb

Wait for the mongodb-v1 pod to run before running the setup script.

This will create the test database bookinfo rating-v2 service will connect to.

```sh
./ingress-mongodb-setup-tls.sh
```

### Test the bookinfo application connectivity to mongodb

Open the following url in a web browser.

```sh
echo "https://$(oc get route ${control_plane_route_name} -n ${control_plane_namespace} -o jsonpath={'.spec.host'})/productpage"
```

Refresh the product info page multiple times. If all was successful, you should see Reviewer 1 with a one star review under Book Reviews.

> TODO: figure out why some requests fail to mongodb intermittently. Perhaps there is a connection setting or timeout within the database that needs to be configured.

Within Kiali, all reviews requests should be directed to the rating-v2 service and then to the mongodb ServiceEntry.

You won't see traffic in kiali for mongodb requests since it is not using http or grcp, just tcp.

### Cleanup mongo gateway configuration

```sh
./cleanup-mongo-gateway-configuration.sh
```

### Cleanup control plane mongodb

```sh
./cleanup-service-mesh-control-plane-mongodb.sh
```

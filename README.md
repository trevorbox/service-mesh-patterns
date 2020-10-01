# Service Mesh Patterns

This project provides examples for widely practiced Service Mesh configurations.

> To update git submodules to latest commit use:
>
> `git submodule update --init --recursive`
>
> `git submodule foreach git pull origin master`

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
export bookinfo_namespace=bookinfo
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

This example is based on the blog post [Consuming External MongoDB Services](https://istio.io/latest/blog/2018/egress-mongo/) but takes it a step further to show how to deploy a MongoDB instance behind the same Service Mesh on Openshift and expose it via an External Load Balancer on the mongo ingress gateway for external communication. With this configuration we can present a certificate in the mongo-ingressgateway proxy and test TLS connections from outside the mesh to MongoDB.

The bookinfo application is also deployed with an additional ratings-v2 service that connects to MongoDB via a ServiceEntry to the NodePort with TLS.

The updated architecture of the bookinfo app appears below:

![Updated Bookinfo architecture with mongodb in mesh](./documentation/pictures/bookinfo-mongo.png)

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

Refresh the product info page multiple times. If all was successful, you should see Reviewer 1 with a one star rating under Book Reviews.

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

## Multiple Ingress Gateways and Egress Gateway to MongoDB

This example is also based on the blog post [Consuming External MongoDB Services](https://istio.io/latest/blog/2018/egress-mongo/#configure-tcp-traffic-from-sidecars-to-the-egress-gateway)

The mongo service still exists in the same location as the previous example's architecture describes.

Direct mongo traffic through an egress gateway:

![Kiali mongodb traffic through an egressgateway](./documentation/pictures/bookinfo-mongo-egressgateway.png)

### Install control plane mongodb via egressgateway

```sh
./install-service-mesh-control-plane-mongodb-egressgateway.sh
```

### Install mongo egressgateway configuration

```sh
./install-mongo-egressgateway-configuration.sh
```

### Configure mongodb

Wait for the mongodb-v1 pod to run before running the setup script.

This will create the test database bookinfo rating-v2 service will connect to.

```sh
./ingress-mongodb-setup-tls.sh
```

### Verify traffic flows through the egressgateway

Open the following url in a web browser.

```sh
echo "https://$(oc get route ${control_plane_route_name} -n ${control_plane_namespace} -o jsonpath={'.spec.host'})/productpage"
```

Refresh the product info page multiple times. If all was successful, you should see Reviewer 1 with a one star rating under Book Reviews.

> Note: the External Load Balancer host's IP can change to the mongo-ingressgateway kubernetes service on AWS. If that happens you will need to rerun install-mongo-egressgateway-configuration.sh to update the IP address of the direct-mongo-through-egress-gateway VirtualService and mongodb ServiceEntry.

The istio-proxy access logs within the istio-egrassgateway pod should show outbound traffic from it. This logging was enabled by the servicemeshcontrolplane's `global.proxy.accessLogFile` configuration.

```sh
[2020-07-22T00:38:16.510Z] "- - -" 0 - "-" "-" 1536 3960 24 - "-" "-" "-" "-" "13.58.124.191:27018" outbound|27018||my-mongo.tcp.svc 10.130.0.166:43250 10.130.0.166:15666 10.130.0.170:54548 - -
```

### Cleanup mongo egressgateway configuration

```sh
./cleanup-mongo-egressgateway-configuration.sh
```

### Cleanup control plane mongodb egressgateway

```sh
./cleanup-service-mesh-control-plane-mongodb-egressgateway.sh
```

## Egress Traffic Control

This example demonstrates controlling outgoing traffic from the service mesh to external services.  Priorities are applied based on the header that is provided with the request.  In a real scenario this will most likely be injected based on some form of authentication and authorization.  The example also provides samples to demonstrate the limits that are applied to the different service levels based on Istio destination rules using subsets for the external service.

This [guide](https://github.com/cloudfirst-dev/istio-egress-traffic-control) will walk through running the examples.

## Originate TLS through an Egress Gateway with a trusted CA Certificate

- See http TLS origination example [README.md](egressgateway/http-trusted-ca/).
- See mongo TLS origination example [README.md](egressgateway/mongodb-trusted-ca/).

# Service Mesh Patterns

This project provides examples for widely practiced Service Mesh configurations.

> NOTE: These examples assume the control plane is already deployed.
> To deploy the mesh, follow the instructions in the [trevorbox/service-mesh](https://github.com/trevorbox/service-mesh) project.

## Setup

Export Default vars

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

Deploy

```sh
./deploy-basic-gateway-configuration.sh
```

Test the bookinfo application

```sh
# Open the following url in a web browser
echo "https://$(oc get route ${control_plane_route_name} -n ${control_plane_namespace} -o jsonpath={'.spec.host'})/productpage"
```

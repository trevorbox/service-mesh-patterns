# Service Mesh Patterns

This project provides examples for widely practiced Service Mesh configurations.

> NOTE: These examples assume the control plane is already deployed.
> To deploy the mesh, follow the instructions in the [trevorbox/service-mesh](https://github.com/trevorbox/service-mesh) project.

## Basic Gateway Configuration

This example demonstrates a basic confiuration using:

- A single Gateway deployed in the *"<control_plane_namespace>"*.
- A VirtualService deployed in the member namespace referencing the Gateway in *"<control_plane_namespace>/<gateway_name>"*.

Review the contents of [deploy-basic-gateway-configuration.sh](deploy-basic-gateway-configuration.sh) to learn what variables to modify and how run the helm template.



```sh
./deploy-basic-gateway-configuration.sh
```

# Basic Gateway Configuration

This example demonstrates a basic confiuration using:

- A single Gateway deployed in the *"<control_plane_namespace>"*.
- VirtualService deployed in the member namespace referencing the Gateway in *"<control_plane_namespace>/<gateway_name>"*.

Review the contents of `deploy.sh` to learn what variables to modify and how run the helm template.

```sh
./deploy.sh
```

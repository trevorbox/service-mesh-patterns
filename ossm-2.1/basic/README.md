# OSSM 2.0 basic example

This example demonstrates a production or dev control plane deployment option using OSSM 2.0.

## Install Operators

```sh
helm upgrade -i service-mesh-operators -n openshift-operators-redhat helm/service-mesh-operators --create-namespace
```

## Setup

```sh
export istio_system_namespace=istio-system
```

## Install Control Plane

For Dev (no elasticsearch storage for Jaeger traces)...

```sh
helm upgrade --create-namespace -i control-plane -n ${istio_system_namespace} helm/control-plane
```

For Production...

```sh
helm upgrade --create-namespace -i control-plane -n ${istio_system_namespace} helm/control-plane --set is_production_deployment=true
```

## Install Bookinfo Istio Configs

```sh
helm upgrade --create-namespace -i bookinfo-istio helm/bookinfo-istio -n bookinfo --set control_plane.ingressgateway.host=$(oc get route api -n ${istio_system_namespace} -o jsonpath={'.spec.host'})
```

## Install Bookinfo

```sh
helm upgrade --create-namespace -i bookinfo helm/bookinfo -n bookinfo
```

## Test Bookinfo

```sh
echo "Navigate to https://$(oc get route api -n ${istio_system_namespace} -o jsonpath={'.spec.host'})/productpage"
```

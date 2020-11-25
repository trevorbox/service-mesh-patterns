# OSSM 2.0

This example demonstrates an Openshift passthrough route to an ingress gateway that presents a cert-manager certificate using SDS.

## Install Operators

```sh
helm upgrade -i service-mesh-operators -n openshift-operators helm/service-mesh-operators
```

## Install Cert Manager for Passthrough route TLS

```sh
oc apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v1.0.4/cert-manager.yaml
oc new-project istio-system
helm upgrade -i --create-namespace -n cert-manager cert-manager helm/cert-manager
```

## Install Control Plane

```sh
helm upgrade --create-namespace -i control-plane -n istio-system helm/control-plane
```

## Install Bookinfo Istio Configs

```sh
helm upgrade --create-namespace -i bookinfo-istio helm/bookinfo-istio -n bookinfo --set control_plane.ingressgateway.host=$(oc get route api -n istio-system -o jsonpath={'.spec.host'})
```

## Install Bookinfo

```sh
helm upgrade --create-namespace -i bookinfo helm/bookinfo -n bookinfo
```

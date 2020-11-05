# OSSM 2.0

## Install Operators

```sh
helm upgrade -i service-mesh-operators -n openshift-operators helm/service-mesh-operators
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

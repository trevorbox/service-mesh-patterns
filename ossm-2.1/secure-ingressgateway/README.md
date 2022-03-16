# Secure Ingress Gateway

This example demonstrates an Openshift passthrough route to an ingress gateway that presents a cert-manager certificate using SDS.

## Install Operators

```sh
helm upgrade -i service-mesh-operators -n openshift-operators-redhat helm/service-mesh-operators --create-namespace
```

## Install Cert Manager for Passthrough route TLS

```sh
oc new-project istio-system
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --version v1.7.1 \
  --create-namespace \
  --set installCRDs=true
```

## Setup

```sh
export istio_system_namespace=istio-system
```

## Create certificate for ingressgateway

```sh
helm upgrade -i --create-namespace -n ${istio_system_namespace} cert-manager-certs helm/cert-manager --set ingressgateway.cert.commonName=api-${istio_system_namespace}.$(oc get ingress.config.openshift.io cluster -o jsonpath={.spec.domain})
```

## Install Control Plane

```sh
helm upgrade --create-namespace -i control-plane -n ${istio_system_namespace} helm/control-plane
```

## Install Bookinfo Istio Configs

```sh
helm upgrade --create-namespace -i bookinfo-istio helm/bookinfo-istio -n bookinfo --set control_plane.ingressgateway.host=$(oc get route api -n ${istio_system_namespace} -o jsonpath={'.spec.host'})
```

## Install Bookinfo

```sh
helm upgrade --create-namespace -i bookinfo helm/bookinfo -n bookinfo
```

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
  --version v1.10.1 \
  --create-namespace \
  --set installCRDs=true
```

## Setup

```sh
export istio_system_namespace=istio-system
export istio_ingress_namespace=istio-ingress
```

## Create certificate for ingressgateway

```sh
helm upgrade -i --create-namespace -n ${istio_ingress_namespace} cert-manager-certs helm/cert-manager --set ingressgateway.cert.commonName=api-${istio_ingress_namespace}.$(oc get ingress.config.openshift.io cluster -o jsonpath={.spec.domain})
```

## Install Control Plane

```sh
helm upgrade --create-namespace -i control-plane -n ${istio_system_namespace} helm/control-plane
```

## Helmchart for istio gateway injection

```sh
# Taken from...
# helm repo add istio https://istio-release.storage.googleapis.com/charts
# helm repo update
# helm install istio-ingressgateway istio/gateway -n istio-ingress
helm upgrade -i istio-ingressgateway helm/injected-gateway -n ${istio_ingress_namespace}
```

## Install Bookinfo Istio Configs

```sh
helm upgrade --create-namespace -i bookinfo-istio helm/bookinfo-istio -n bookinfo --set ingressgateway.host=$(oc get route api -n ${istio_ingress_namespace} -o jsonpath={'.spec.host'})
```

## Install Bookinfo

```sh
helm upgrade --create-namespace -i bookinfo helm/bookinfo -n bookinfo
```

## Install nginx-echo-headers Istio Configs

```sh
helm upgrade --create-namespace -i nginx-echo-headers-istio helm/nginx-echo-headers-istio -n nginx-echo-headers
```

## Install nginx-echo-headers

```sh
helm upgrade --create-namespace -i nginx-echo-headers helm/nginx-echo-headers -n nginx-echo-headers
```

## Test nginx-echo-headers

```sh
curl -ik https://api-${istio_ingress_namespace}.$(oc get ingress.config.openshift.io cluster -o jsonpath={.spec.domain})/nginx-echo-headers
```

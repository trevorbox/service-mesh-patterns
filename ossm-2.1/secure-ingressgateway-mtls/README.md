# Secure Ingress Gateway mTLS

This example demonstrates an Openshift passthrough route to an ingress gateway that requires mutual TLS (mTLS).

By using mutual TLS, we can also create an [AuthorizationPolicy](./helm/nginx-echo-headers-istio/templates/authorizationpolicy-nginx-echo-headers.yaml) to verify the Common Names of certificates. An [EnvoyFilter](./helm/nginx-echo-headers-istio/templates/envoyfilter-subject-peer-certificate-header.yaml) is also required since widlcard values in the rule matching logic is limited on AuthorizationPolicies see [authorization-policy/#Rule](https://istio.io/latest/docs/reference/config/security/authorization-policy/#Rule) from the docs.

## Concepts for authn/z with mtls

TLS authentication occurs when the cert chain can be trusted. It is not possible to trust an individual intermediate CA for authentication, since the rootCA must also be trusted in order to complete the chain. In order to trust the client certificate chain, an mTLS gateway should only trust the rootCA (and thus trust any intermediate CAs as well). Clients can send their workload and intermediate certificates, excluding the rootCA, to complete the chain for the mTLS gateway to authenticate.

After authentication works, you can authorize a workload certificate's Common Name. This is possible because the client presents its own certificate but you need a header or some other way to pass the workload's common name to the next service in the mesh. Obviously, the authroization *could* be compromised if someone issues multiple worklaod certificates with the same Common Names using the same issuer, but that would indicate a deeper problem with an organization's cert management system/process (or the pki is compromised).

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

## Create secret for mtls

```sh
oc get secret ingressgateway-cert -o jsonpath={.data.tls\\.crt} -n istio-system | base64 -d > /tmp/tls.crt
oc get secret ingressgateway-cert -o jsonpath={.data.tls\\.key} -n istio-system | base64 -d > /tmp/tls.key
# trust the rootca common to all workloads for authentication
oc get secret ingressgateway-rootca -o jsonpath={.data.ca\\.crt} -n istio-system | base64 -d > /tmp/ca.crt

oc create -n istio-system secret generic ingressgateway-mtls --from-file=tls.key=/tmp/tls.key \
--from-file=tls.crt=/tmp/tls.crt --from-file=ca.crt=/tmp/ca.crt
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

## Install nginx-echo-headers Istio Configs

```sh
helm upgrade --create-namespace -i nginx-echo-headers-istio helm/nginx-echo-headers-istio -n nginx-echo-headers
```

## Install nginx-echo-headers

```sh
helm upgrade --create-namespace -i nginx-echo-headers helm/nginx-echo-headers -n nginx-echo-headers
```

## test nginx-echo-headers

### successful authentication and authorization

The workload certificate from ingressgateway-cert should authenticate and authorize since its a tls certificate created from the same trusted root CA AND it has the CommonName we want to trust...

```sh
oc get secret ingressgateway-cert -o jsonpath={.data.tls\\.crt} -n istio-system | base64 -d > /tmp/tls.crt
oc get secret ingressgateway-cert -o jsonpath={.data.tls\\.key} -n istio-system | base64 -d > /tmp/tls.key
oc get secret ingressgateway-cert -o jsonpath={.data.ca\\.crt} -n istio-system | base64 -d > /tmp/ca.crt
curl -i https://api-istio-system.apps-crc.testing/nginx-echo-headers --cert /tmp/tls.crt --key /tmp/tls.key --cacert /tmp/ca.crt
```

output...

```sh
$ curl -i https://api-istio-system.apps-crc.testing/nginx-echo-headers --cert /tmp/tls.crt --key /tmp/tls.key --cacert /tmp/ca.crt
HTTP/2 200 
server: istio-envoy
date: Tue, 10 May 2022 23:53:43 GMT
content-type: text/plain
x-envoy-upstream-service-time: 1

GET /nginx-echo-headers HTTP/1.1
host: api-istio-system.apps-crc.testing
user-agent: curl/7.79.1
accept: */*
x-forwarded-for: 10.217.0.1
x-forwarded-proto: https
x-request-id: 7ee319ff-817e-419c-8ae2-dbf37ae5b53c
x-forwarded-client-cert: Hash=7020db7c5f56d49340352b835d8fd6b9acdc325f9254101e5d4297b1063842b3;Cert="-----BEGIN%20CERTIFICATE-----%0AMIIDJzCCAg%2BgAwIBAgIRAJGhybpZCUxr43zNf1a3RJswDQYJKoZIhvcNAQELBQAw%0AIDEeMBwGA1UEAxMVY2Euc3ViY2EuY2VydC1tYW5hZ2VyMB4XDTIyMDUwOTE3Mjky%0AOVoXDTIyMDgwNzE3MjkyOVowLDEqMCgGA1UEAxMhYXBpLWlzdGlvLXN5c3RlbS5h%0AcHBzLWNyYy50ZXN0aW5nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA%0A2Dj7OFffGl9ZRz5sgDK0GerKBKZoNBSvNUU0DzCat01XY5%2FIx3fb6R1WLS8fBhl2%0A0isPDQE44O2NxvVAYep3l0jIJh3VrWW9rObgEauKNzrE43zP86FaeO0RkuPFSJVw%0Ay4HSkocHj%2FT3Y8413gdZmj3eRGcTmoGOSXuComEaAHMCHQHLRs4X%2F4cT6CBI8g5u%0AIcL4L1%2FHyfwen9jKl7a6pC5jOq7MZNpxz6aNUhlPZDwaVI3VS4%2FBxDLqhlrZF0rN%0Af%2FydwoSKt3BF61m3S5zt53S1QdRLi5aCBwVcxbb8zsD%2FI8KDnLlhieAdaZi4DMxL%0ADSqn7QWnQjnrdTf1iodVgQIDAQABo1AwTjAdBgNVHSUEFjAUBggrBgEFBQcDAQYI%0AKwYBBQUHAwIwDAYDVR0TAQH%2FBAIwADAfBgNVHSMEGDAWgBTrpweawMnZF3H4jdnz%0AQCJ1x4FAejANBgkqhkiG9w0BAQsFAAOCAQEA1BXvLIuOOHwCUp2rWx94isDbIH3%2B%0A6dh%2BzaUB3On4tC4UL9ibYuezFbap0gCMUbVor2lcC56p1F%2BPLEYCopv89NXza0%2FP%0A7jr%2B3kpdNnTfaDATQ8CpCeNZnH5toWvsKXqPNNM0F9FRVZTRyx1MXhTfKexFUccb%0AFKPs67TLiRrSSHZXiCzwClRQdNoenEwMVY5XJVayYMCDs3EiWk7SWsf%2FVm%2FHGnTN%0AoRevZIAli9jsibcBaNRuWo7b%2BrLh8YzcYf3i1we5ufdzlZ22fhDvidCX7GXjAj2s%0AiCEBWK9oH649Fs8mPbf1AmHjYFR9BIfMPxB5%2Fm08WxFjK8iT2RYqh4KCPg%3D%3D%0A-----END%20CERTIFICATE-----%0A";Subject="CN=api-istio-system.apps-crc.testing";URI=,By=spiffe://cluster.local/ns/nginx-echo-headers/sa/nginx-echo-headers;Hash=07283f6585ccc3b09a5af8483973cf2e84e2b55476092207dbe4fc4887a78438;Subject="";URI=spiffe://cluster.local/ns/istio-system/sa/custom-ingressgateway-service-account
x-forwarded-client-cert-subject-dn: CN=api-istio-system.apps-crc.testing
x-envoy-attempt-count: 1
content-length: 0
x-envoy-internal: true
x-b3-traceid: 6356edc4ae0b7770b08656d21c997871
x-b3-spanid: 4a711b97c820eb54
x-b3-parentspanid: b08656d21c997871
x-b3-sampled: 0



nginx-echo-headers-58b78f68cc-8qjxt
```

### successful authentication fail authorization

The other workload cert from ingressgateway-cert2 should not be authorized since the common name does not match, however the tls authenticates...

```sh
oc get secret ingressgateway-cert2 -o jsonpath={.data.tls\\.crt} -n istio-system | base64 -d > /tmp/tls2.crt
oc get secret ingressgateway-cert2 -o jsonpath={.data.tls\\.key} -n istio-system | base64 -d > /tmp/tls2.key
oc get secret ingressgateway-cert2 -o jsonpath={.data.ca\\.crt} -n istio-system | base64 -d > /tmp/ca2.crt

curl -i https://api-istio-system.apps-crc.testing/nginx-echo-headers --cert /tmp/tls2.crt --key /tmp/tls2.key --cacert /tmp/ca2.crt
```

output...

```sh
$ curl -i https://api-istio-system.apps-crc.testing/nginx-echo-headers --cert /tmp/tls2.crt --key /tmp/tls2.key --cacert /tmp/ca2.crt
HTTP/2 403 
content-length: 19
content-type: text/plain
date: Tue, 10 May 2022 23:51:33 GMT
server: istio-envoy
x-envoy-upstream-service-time: 0

RBAC: access denied
```

### fail authentication

The other workload cert from ingressgateway-cert-bad should not authenticate since our gateway doesnt trust the same rootCA...

```sh
oc get secret ingressgateway-cert-bad -o jsonpath={.data.tls\\.crt} -n istio-system | base64 -d > /tmp/tls-bad.crt
oc get secret ingressgateway-cert-bad -o jsonpath={.data.tls\\.key} -n istio-system | base64 -d > /tmp/tls-bad.key
oc get secret ingressgateway-rootca -o jsonpath={.data.ca\\.crt} -n istio-system | base64 -d > /tmp/ca-bad.crt

curl -I https://api-istio-system.apps-crc.testing/nginx-echo-headers --cert /tmp/tls-bad.crt --key /tmp/tls-bad.key --cacert /tmp/ca-bad.crt
```

output...

```sh
$ curl -I https://api-istio-system.apps-crc.testing/nginx-echo-headers --cert /tmp/tls-bad.crt --key /tmp/tls-bad.key --cacert /tmp/ca-bad.crt
curl: (56) OpenSSL SSL_read: error:14094418:SSL routines:ssl3_read_bytes:tlsv1 alert unknown ca, errno 0
```

similarly, if you dont present any client certificate the authentication should also fail...

```sh
curl -I https://api-istio-system.apps-crc.testing/nginx-echo-headers --cacert /tmp/ca.crt
```

output...

```sh
$ curl -I https://api-istio-system.apps-crc.testing/nginx-echo-headers --cacert /tmp/ca.crt
curl: (56) OpenSSL SSL_read: error:1409445C:SSL routines:ssl3_read_bytes:tlsv13 alert certificate required, errno 0
```

## test bookinfo

### successful authentication

Since we dont have an authorizationpolicy for the productpage (bookinfo app route) the other workload certificate ingressgateway-cert2 should be able to authenticate

```sh
oc get secret ingressgateway-cert2 -o jsonpath={.data.tls\\.crt} -n istio-system | base64 -d > /tmp/tls2.crt
oc get secret ingressgateway-cert2 -o jsonpath={.data.tls\\.key} -n istio-system | base64 -d > /tmp/tls2.key
oc get secret ingressgateway-cert2 -o jsonpath={.data.ca\\.crt} -n istio-system | base64 -d > /tmp/ca2.crt
curl -I https://api-istio-system.apps-crc.testing/productpage --cert /tmp/tls2.crt --key /tmp/tls2.key --cacert /tmp/ca2.crt
```

output...

```sh
$ curl -I https://api-istio-system.apps-crc.testing/productpage --cert /tmp/tls2.crt --key /tmp/tls2.key --cacert /tmp/ca2.crt
HTTP/2 200 
content-type: text/html; charset=utf-8
content-length: 5723
server: istio-envoy
date: Wed, 11 May 2022 00:14:19 GMT
x-envoy-upstream-service-time: 30
```

This demonstrates how we can choose to authorize certain requests using mtls. The authentication requirements are the same, however.

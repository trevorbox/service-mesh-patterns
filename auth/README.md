# Authentication w/mtls & jwt

See [Authentication Policy](https://istio.io/v1.4/docs/reference/config/security/istio.authentication.v1alpha1/)

This example uses the bookinfo app to demonstrate ORIGIN and PEER authentication to the productpage service. The oauth2 proxy in the gateway will take care of passing the authorization header to productpage after the user logs into Okta - required for ORIGIN authentication. mtls is handled for us by Istio - required for PEER authentication.

Additionally, we are adding headers to the request using an Istio Rule to demonstrate the jwt claims, request auth principal and source principal.

> Note: since productpage won't natively propagate the authroization header, we can't use the same Policy on other downstream services.

## Setup

Follow the steps described within [Configuring the OIDC Provider with Okta](https://github.com/trevorbox/oauth2-proxy/blob/update-okta-doc/docs/2_auth.md#configuring-the-oidc-provider-with-okta) to create an Okta application & authorization server. Retrieve its `client_id` and `client_secret`.

> Note: the Okta Application needs the login redirect URI to match the ${redirect_url} defined below.

```sh
export istio_system_namespace=istio-system
export bookinfo_namespace=bookinfo
export client_id=<your_client_id>
export client_secret=<your_client_secret>
export redirect_url="https://api-${istio_system_namespace}.$(oc get route console -o jsonpath={.status.ingress[0].routerCanonicalHostname} -n openshift-console)/oauth2/callback"
```

## Deploy Control Plane

```sh
helm upgrade -i control-plane-oauth2 --create-namespace -n ${istio_system_namespace} --set client_id=${client_id} --set client_secret=${client_secret} --set redirect_url=${redirect_url} helm/control-plane-oauth2
```

## Deploy Istio Configs

```sh
helm upgrade --create-namespace -i bookinfo-istio helm/bookinfo-istio -n ${bookinfo_namespace} --set control_plane.ingressgateway.host=$(oc get route api -n ${istio_system_namespace} -o jsonpath={'.spec.host'}) --set control_plane.namespace=${istio_system_namespace}
```

## Deploy App

```sh
helm upgrade --create-namespace -i bookinfo helm/bookinfo -n ${bookinfo_namespace}
```

## Verify Authentication for Origin works

Bookinfo should work because it passed the jwt auth header after authenticating from the oauth2-proxy...

```sh
echo "Open this page: https://$(oc get route api -n ${istio_system_namespace} -o jsonpath={'.spec.host'})/productpage"
```

Requests without a valid jwt should return `401 Unauthorized`...

```sh
oc exec deploy/ratings-v1 -c ratings -n ${bookinfo_namespace} -i -t -- /bin/bash -c "curl -I http://productpage:9080"
```

To verify the request headers is passed to the application container...

```sh
echo Open this page: https://api-${istio_system_namespace}.$(oc get route console -o jsonpath={.status.ingress[0].routerCanonicalHostname} -n openshift-console)/nginx-echo-headers
```

You can also enable debug level logs on the sidecar...

```sh
istioctl pc log $(oc get pod -l app=productpage -n ${bookinfo_namespace} -o jsonpath='{.items[0].metadata.name}') --level debug -n ${bookinfo_namespace}
```

## Deploy RHACM apps to Hub

```sh
helm upgrade -i --create-namespace servicemeshoperators .deploy-rhacm/helm/servicemeshoperators -n global-operators
helm upgrade -i --create-namespace control-plane .deploy-rhacm/helm/control-plane-oauth2 -n istio-system
helm upgrade -i --create-namespace bookinfo-istio .deploy-rhacm/helm/bookinfo-istio -n bookinfo
helm upgrade -i --create-namespace bookinfo .deploy-rhacm/helm/bookinfo -n bookinfo
```

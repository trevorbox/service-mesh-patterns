# Authentication and Authorization w/mTLS & JWT

> Note: OSSM 2.0 requires OCP 4.6+

See [Security](https://istio.io/v1.6/docs/reference/config/security/)

This example demonstrates request (JWT) and peer (mTLS) authentication & authorization to the bookinfo app's productpage and nginx-echo-headers services. Only requests originating from the ingressgateway with a valid JWT will be authorized to each service. The oauth2 proxy sidecar in the ingressgateway will pass the authorization header to the productpage or nginx-echo-headers services after the user logs into Okta (required for request authentication). mTLS is handled for us by Istio (required for peer authentication).

Additionally, we are adding headers to the request using an EnvoyFilter to demonstrate the JWT claims, request auth principal and source principal. These headers can be viewed by the nginx-echo-headers service.

> Note: since productpage won't natively propagate the authroization header, we can't use the same authorization policies on other upstream services (reviews, details, ratings).

## Setup

Follow the steps described within [Configuring the OIDC Provider with Okta](https://github.com/trevorbox/oauth2-proxy/blob/update-okta-doc/docs/2_auth.md#configuring-the-oidc-provider-with-okta) to create an Okta application & authorization server. Retrieve its `client_id` and `client_secret`.

> Note: the Okta Application needs the login redirect URI to match the ${redirect_url} defined below.

```sh
export istio_system_namespace=istio-system
export apps_namespace=bookinfo
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
helm upgrade --create-namespace -i apps-istio helm/apps-istio -n ${apps_namespace} --set control_plane.ingressgateway.host=$(oc get route api -n ${istio_system_namespace} -o jsonpath={'.spec.host'}) --set control_plane.namespace=${istio_system_namespace}
```

## Deploy App

```sh
helm upgrade --create-namespace -i apps helm/apps -n ${apps_namespace}
```

## Verify

### Verify Authentication & Authentication for Requests and Peers works

Bookinfo should work because it passed the JWT auth header after authenticating from the oauth2-proxy...

```sh
echo "Open this page: https://$(oc get route api -n ${istio_system_namespace} -o jsonpath={'.spec.host'})/productpage"
```

Requests from the ratings pod without a valid JWT should return `403 Forbidden`...

```sh
oc exec deploy/ratings-v1 -c ratings -n ${apps_namespace} -i -t -- /bin/bash -c "curl -I http://productpage:9080"
```

You can try changing the AuthorizationPolicy's `source.principals` to something other than the ingressgateway's service account to demonstrate forbidden access from the ingressgateway pod with a valid JWT as well. For example change authorizationpolicy-productpage.yaml to the following, run the helm upgrade command to redeploy the istio configs, and then open the bookinfo page again.

```yaml
---
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: productpage
spec:
  selector:
    matchLabels:
      app: productpage
  rules:
  - from:
    # Require a valid jwt for all requests from a fake service account only
    - source:
        requestPrincipals:
          - "*"
        principals:
          - "my_fake_principal"
...
```

You can also enable debug level logs on the sidecar for more info...

```sh
istioctl pc log $(oc get pod -l app=productpage -n ${apps_namespace} -o jsonpath='{.items[0].metadata.name}') --level debug -n ${apps_namespace}
```

### Verify custom headers passed to the nginx-echo-headers container

Since we deployed the echo headers app we can directly see what headers are finally passed to the application container by just accessing the page in the browser...

```sh
echo Open this page: https://api-${istio_system_namespace}.$(oc get route console -o jsonpath={.status.ingress[0].routerCanonicalHostname} -n openshift-console)/nginx-echo-headers
```

Enable the info logs on the nginx-echo-headers sidecar to view the same additional headers in the sidecar logs...

```sh
istioctl pc log $(oc get pod -l app=nginx-echo-headers -n ${apps_namespace} -o jsonpath='{.items[0].metadata.name}') --level info -n ${apps_namespace}
```

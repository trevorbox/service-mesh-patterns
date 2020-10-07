# TLS origination

In attempting to originate TLS through an egress gateway and trust a ca certificate I found a strange behavior with the DestinationRule's exportTo functionality. Since the certificate needs to be mounted on the egress gateway pod only I believe we need to use exportTo: '.' for the DestinationRule that originates tls in the control plane namespace. This causes the request to fail however - even without any ca certificate defined and TLS mode SIMPLE. The egress gateway envoy log states "upstream_reset_before_response_started{connection termination}" and fails with a 503 error (see istio-egressgateway-503-error.log).
How should the DestinationRule be configured for this use case? Is there any example available?

Example service mesh, application and egress gateway deployment can be found here to replicate the use case.

## Install Service Mesh Operators

```sh
cd ..
helm install service-mesh-operators -n openshift-operators service-mesh/service-mesh-operators/
```

OR

```sh
oc apply -f yaml/service-mesh-operators.yaml
```

## Create root ca configmap

```sh
oc new-project istio-system

oc get secrets -n openshift-ingress-operator router-ca -o jsonpath='{.data.tls\.crt}' | base64 -d > /tmp/ca.crt
oc -n istio-system create configmap ocp-ca-bundle --from-file=/tmp/ca.crt
```

## Install the control plane

```sh
helm upgrade -i control-plane -n istio-system control-plane
```

OR

```sh
oc apply -f yaml/control-plane.yaml
```

## Install the bookinfo application to test tls origination from

```sh
cd ..
source default-vars.txt && export $(cut -d= -f1 default-vars.txt)
./install-basic-gateway-configuration.sh
```

OR

> Note: you will need to manually change the api gateway host throughout the basic-gateway-configuration.yaml file.

```sh
oc apply -f yaml/basic-gateway-configuration.yaml
oc apply -f yaml/bookinfo.yaml
```

> TODO figure out how to add the configmap volumemount - doing that manually right now since the istio operator does not seem to mount the volume to the proxy, though it does create the volume

## Create test instance to TLS originate to outside the mesh

```sh
oc new-project mesh-external

oc new-app centos/nginx-112-centos7~https://github.com/sclorg/nginx-ex -n mesh-external

oc create route edge nginx --service=nginx-ex --port 8080 -n mesh-external
```

## Install the egressgateway configurations

```sh
helm upgrade -i egress -n bookinfo egressgateway-tls-origination --set nginx.host=$(oc get route nginx -n mesh-external -o jsonpath={.spec.host})
```

OR

> Note: you will need to manually change the nginx host throughout the egressgateway-tls-origination.yaml file.

```sh
oc apply -f yaml/egressgateway-tls-origination.yaml
```

## Helpful test commands

```sh
# Test from mesh pod
oc rsh -n bookinfo -c ratings deployment/ratings-v1 curl -v http://$(oc get route nginx -n mesh-external -o jsonpath={.spec.host})

# Test from egressgateway
oc rsh -n istio-system -c istio-proxy deployment/istio-egressgateway curl -v https://$(oc get route nginx -n mesh-external -o jsonpath={.spec.host}) --cacert /etc/configmaps/ocp-ca-bundle/ca.crt

# show routes
istioctl pc route $(oc get pod -l app=ratings -n bookinfo -o jsonpath='{.items[0].metadata.name}') -n bookinfo --name 80 -o json

istioctl pc route $(oc get pod -l app=istio-egressgateway -n istio-system -o jsonpath='{.items[0].metadata.name}') -n istio-system --name http.80 -o json

# change log level
istioctl pc log $(oc get pod -l app=istio-egressgateway -n istio-system -o jsonpath='{.items[0].metadata.name}') --level debug -n istio-system
```

## Case 02754767

Install the operators

```sh
oc apply -f yaml/1_service-mesh-operators.yaml
```

Create namespaces

```sh
oc new-project istio-system
oc new-project mesh-external
oc new-project bookinfo
```

Add the router ca secret

```sh
oc get secrets -n openshift-ingress-operator router-ca -o jsonpath='{.data.tls\.crt}' | base64 -d > /tmp/ca.crt
oc create secret generic ocp-ca-bundle --from-file=/tmp/ca.crt -n istio-system
```

Create the control plane

```sh
oc apply -f yaml/2_control-plane.yaml -n istio-system
```

> Wait for the control plane to install

Create an nginx service outside of the mesh

```sh
oc new-app centos/nginx-112-centos7~https://github.com/sclorg/nginx-ex -n mesh-external

oc create route edge nginx --service=nginx-ex --port 8080 -n mesh-external
```

> Wait for the nginx app to build and deploy

Test that nginx is working

```sh
#test that the application is reachable from your laptop (status 200)
curl -I https://$(oc get route nginx -n mesh-external -o jsonpath={.spec.host}) --cacert /tmp/ca.crt
```

Install istio configrations

```sh
oc process -f yaml/3_template-configuration.yaml \
  API_HOST=$(oc get route api -n istio-system -o jsonpath='{.spec.host}') \
  NGINX_HOST=$(oc get route nginx -n mesh-external -o jsonpath='{.spec.host}') \
  | oc apply -f -
```

Install bookinfo

```sh
oc apply -f yaml/4_bookinfo.yaml
```

Notice that traffic from the bookinfo pod does not work and returns a 503. You use a normal http request since the egressgateway originates TLS.

```sh
oc rsh -n bookinfo -c ratings deployment/ratings-v1 curl -v http://$(oc get route nginx -n mesh-external -o jsonpath={.spec.host})
```

Additionally, the destinationrule "originate-tls-for-nginx-mesh-external" does not modify the envoy routing on the istio-egressgateway pod when exportTo is set to "." within the istio-system namespace.

```sh
istioctl pc route $(oc get pod -l app=istio-egressgateway -n istio-system -o jsonpath='{.items[0].metadata.name}') -n istio-system --name http.80 -o json
```

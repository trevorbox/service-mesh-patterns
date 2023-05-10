# oracledb-free

<https://github.com/oracle/docker-images/tree/main/OracleDatabase/SingleInstance/samples/kubernetes>ledb-free-
<https://container-registry.oracle.com/ords/f?p=113:1:103217599269754:::1:P1_BUSINESS_AREA:3&cs=3dPc9rp3GGjWwllz-QNYPvkYrSAJbJ9Fy5C1Y08gR8ZEsWCOaw5ce1uQdXfZMr-5kZTvyD_opIiI7tcOz8SOgQQ>

## deploy

```sh
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --version v1.11.0 \
  --create-namespace \
  --set installCRDs=true

helm upgrade -i secure oracledb-free/ -n oracledb-free --create-namespace --set-file scripts.configTcps=configTcps-custom.sh
helm upgrade -i sql sql/ -n oracledb-free
```

## test sql tcp and tcps connection

```sh
oc rsh -c sql -n oracledb-free deploy/sql

# TCP
sql sys/123passwd@//secure-oracledb-free.oracledb-free.svc.cluster.local:1521/FREE as SYSDBA <<EOF
show con_name
exit
EOF

sql sys/123passwd@'(description= (address=(protocol=tcp)(port=1521)(host=secure-oracledb-free.oracledb-free.svc.cluster.local))(connect_data=(service_name=free)))' as SYSDBA <<EOF
show con_name
exit
EOF

# TCPS
sql sys/123passwd@'(description= (address=(protocol=tcps)(port=6666)(host=secure-oracledb-free.oracledb-free.svc.cluster.local))(connect_data=(service_name=FREE))(security=(ssl_server_dn_match=no)))' as SYSDBA <<EOF
show con_name
exit
EOF
```

## notes

```sh
keytool -import -alias oracledb-free -trustcacerts -keystore "/usr/java/jdk-11.0.15/lib/security/cacerts" -file /secrets/ca.crt -storepass changeit -noprompt
keytool -list -keystore /usr/java/jdk-11.0.15/lib/security/cacerts -storepass changeit | egrep oracledb-free

keytool -list -keystore /keystore/truststore.jks -storepass changeit

export WALLET_LOC=/tmp/wallet
orapki wallet create -wallet "${WALLET_LOC}" -auto_login
orapki wallet add -wallet "${WALLET_LOC}" -dn "CN=localhost" -keysize 2048 -self_signed -validity 365
orapki wallet export -wallet "${WALLET_LOC}" -dn "CN=localhost" -cert /tmp/"$(hostname)"-certificate.crt
```

<https://www.funoracleapps.com/2021/03/orapki-quick-reference-and-usage-with.html>

```sh
# openssl pkcs12 -export -in jaydba_blogspot_com_cert.cer -inkey jaydba_blogspot_com.key -cerfile jaydba_blogspot_com_interm.cer -out ewallet.p12


# openssl pkcs12 -export -in /secrets/oracledb-free-cert/tls.crt -inkey /secrets/oracledb-free-cert/tls.key -cerfile interim-tls.crt -out ewallet.p12

WALLET_PWD=
WALLET_LOC="${ORACLE_BASE}/oradata/dbconfig/${ORACLE_SID}/.tls-wallet"

mkdir -p /tmp/server-wallet
openssl pkcs12 -export -in /secrets/oracledb-free-cert/tls.crt -certfile /secrets/oracledb-free-cert/ca.crt -inkey /secrets/oracledb-free-cert/tls.key -out /tmp/server-wallet/ewallet.p12 -passout pass:
orapki wallet create -wallet /tmp/server-wallet -auto_login <<EOF
${WALLET_PWD}
${WALLET_PWD}
EOF
orapki wallet display -wallet /tmp/server-wallet

CLIENT_WALLET_LOC=/tmp/client-wallet
mkdir -p ${CLIENT_WALLET_LOC}
orapki wallet create -wallet "${CLIENT_WALLET_LOC}" -auto_login <<EOF
${WALLET_PWD}
${WALLET_PWD} 
EOF
orapki wallet add -wallet "${CLIENT_WALLET_LOC}" -trusted_cert -cert /tmp/"$(hostname)"-certificate.crt


orapki wallet display -wallet "${WALLET_LOC}"

orapki wallet display -wallet /opt/oracle/oradata/clientWallet/FREE


WALLET_LOC="${ORACLE_BASE}/oradata/dbconfig/${ORACLE_SID}/.tls-wallet"
WALLET_PWD="123passwd"
P12_PWD="123passwd"
orapki wallet import_pkcs12 -wallet "${WALLET_LOC}" -pwd ${WALLET_PWD} -pkcs12file /secrets/oracledb-free-cert/keystore.p12 -pkcs12pwd ${P12_PWD}
```

## Install Operators

```sh
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --version v1.11.0 \
  --create-namespace \
  --set installCRDs=true

oc adm new-project openshift-operators-redhat
oc adm new-project openshift-distributed-tracing
helm upgrade -i service-mesh-operators -n openshift-operators service-mesh-operators --create-namespace
```

## Install Control Plane

```sh
oc new-project istio-ingress
oc new-project
helm upgrade -i control-plane -n istio-system control-plane/ --create-namespace
```

```sh
helm upgrade -i -n cert-manager trust-manager jetstack/trust-manager --wait
helm upgrade -i -n cert-manager trust-bundle trust-bundle/
```

```sh
helm upgrade -i istio-ingressgateway injected-gateway -n istio-ingress --create-namespace \
  --set ingressgateway.cert.commonName=api-istio-ingress.$(oc get ingress.config.openshift.io cluster -o jsonpath={.spec.domain}) \
  --set ingressgateway.host=api-istio-ingress.$(oc get ingress.config.openshift.io cluster -o jsonpath={.spec.domain})
```

```sh
helm upgrade -i secure oracledb-free/ -n oracledb-free --create-namespace --set-file scripts.configTcps=configTcps-custom.sh
oc label namespace oracledb-free inject-mycompany-cabundle=''
```

```sh
helm upgrade -i sql sql/ -n test
helm upgrade -i istio-configs istio-configs/ -n test
```

```sh
oc rsh -c sql -n test deploy/sql

# TCP
sql sys/123passwd@//secure-oracledb-free.oracledb-free.svc.cluster.local:1521/FREE as SYSDBA <<EOF
show con_name
exit
EOF

sql sys/123passwd@'(description= (address=(protocol=tcp)(port=1521)(host=secure-oracledb-free.oracledb-free.svc.cluster.local))(connect_data=(service_name=free)))' as SYSDBA <<EOF
show con_name
exit
EOF

# TCPS
sql sys/123passwd@'(description= (address=(protocol=tcps)(port=6666)(host=secure-oracledb-free.oracledb-free.svc.cluster.local))(connect_data=(service_name=FREE))(security=(ssl_server_dn_match=no)))' as SYSDBA <<EOF
show con_name
exit
EOF
```

## error - istio oracle

```sh
sql sys/123passwd@'(description= (address=(protocol=tcp)(port=32501)(host=oracledb.apps-crc.testing))(connect_data=(service_name=free)))' as SYSDBA <<EOF
show con_name
exit
EOF


sql sys/123passwd@'(description= (address=(protocol=tcp)(port=32501)(host=oracledb.apps-crc.testing))(connect_data=(service_name=free)))' as SYSDBA <<EOF
show con_name
exit
EOF
Picked up JAVA_TOOL_OPTIONS: -Djavax.net.ssl.trustStore=/keystore/truststore.jks -Djavax.net.ssl.trustStorePassword=changeit


SQLcl: Release 23.1 Production on Thu May 04 23:20:44 2023

Copyright (c) 1982, 2023, Oracle.  All rights reserved.

  USER          = sys
  URL           = jdbc:oracle:thin:@(description= (address=(protocol=tcp)(port=32501)(host=oracledb.apps-crc.testing))(connect_data=(service_name=free)))
  Error Message = class oracle.net.nt.TcpNTAdapter cannot be cast to class oracle.net.nt.TcpsNTAdapter (oracle.net.nt.TcpNTAdapter and oracle.net.nt.TcpsNTAdapter are in unnamed module of loader 'app')
Username? (RETRYING) ('sys/*********@(description= (address=(protocol=tcp)(port=32501)(host=oracledb.apps-crc.testing))(connect_data=(service_name=free))) as sysdba'?)   USER          = show con_name
  URL           = jdbc:oracle:thin:@localhost:1521/orcl
  Error Message = IO Error: The Network Adapter could not establish the connection (CONNECTION_ID=E3J4dz6hRCeD3wA59M685g==)
  USER          = show con_name
  URL           = jdbc:oracle:thin:@localhost:1521/xe
  Error Message = IO Error: The Network Adapter could not establish the connection (CONNECTION_ID=bk5F2+e1SoiLIYtPZVpRqA==)
Username? (RETRYING) ('"show con_name"'?) Password? (RETRYING) (**********?)   USER          = exit
  URL           = jdbc:oracle:thin:@localhost:1521/orcl
  Error Message = IO Error: The Network Adapter could not establish the connection (CONNECTION_ID=fTolI96wTR+1EZLOr61qWQ==)
  USER          = exit
  URL           = jdbc:oracle:thin:@localhost:1521/xe
  Error Message = IO Error: The Network Adapter could not establish the connection (CONNECTION_ID=+cbMuvCYTJCUkbupr5QdBg==)
```


```sh
helm upgrade -i istio-egressgateway injected-egress-gateway -n istio-egress
```

```sh
helm upgrade -i -n mongodb mongodb mongo/ --create-namespace
helm upgrade -i mongosh mongosh/ -n test
helm upgrade -i istio-configs istio-configs/ -n test
```

## mysql

```sh

helm upgrade -i mysql-persistent mysql-persistent/ -n mysql --create-namespace
oc label namespace mysql inject-mycompany-cabundle=''

oc rsh -c mysql-community-client deploy/mysql-community-client

MYSQL_PWD="$MYSQL_PASSWORD" mysql -h mysqldb.apps-crc.testing -P 32096 -u user --ssl-mode=VERIFY_IDENTITY --ssl-cert=/secrets/client-cert/tls.crt --ssl-key=/secrets/client-cert/tls.key --ssl-ca=/configmaps/mycompany-cabundle/ca-bundle.crt


MYSQL_PWD="$MYSQL_PASSWORD" mysql -h mysqldb.apps-crc.testing -P 32096 -u user --ssl-mode=VERIFY_IDENTITY --ssl-cert=/secrets/client-cert/tls.crt --ssl-key=/secrets/client-cert/tls.key --ssl-ca=/tmp/ca-bundle.crt
MYSQL_PWD="$MYSQL_PASSWORD" mysql -h mysqldb.apps-crc.testing -P 32096 -u user --ssl-mode=VERIFY_CA --ssl-cert=/secrets/client-cert/tls.crt --ssl-key=/secrets/client-cert/tls.key --ssl-ca=/tmp/ca-bundle.crt


SHOW GRANTS FOR 'user'@'%';

ALTER USER 'user'@'%' REQUIRE SUBJECT 'CN=testclient';
ALTER USER 'user'@'%' REQUIRE X509;

select User,Host,x509_subject from mysql.user where User=user;


helm upgrade -i mysql-community-client mysql-community-client/ -n test
helm upgrade -i istio-configs istio-configs/ -n test
```

## redis

```sh
helm upgrade -i redis redis/ -n redis --create-namespace
helm upgrade -i redis-cli redis-cli/ -n redis

```

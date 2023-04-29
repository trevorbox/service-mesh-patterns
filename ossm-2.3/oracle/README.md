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
sql sys/123passwd@//secure-oracledb-free:1521/FREE as SYSDBA <<EOF
show con_name
exit
EOF

sql sys/123passwd@'(description= (address=(protocol=tcp)(port=1521)(host=secure-oracledb-free))(connect_data=(service_name=free)))' as SYSDBA <<EOF
show con_name
exit
EOF

# TCPS
sql sys/123passwd@'(description= (address=(protocol=tcps)(port=6666)(host=secure-oracledb-free))(connect_data=(service_name=FREE))(security=(ssl_server_dn_match=no)))' as SYSDBA <<EOF
show con_name
exit
EOF
```

## notes

```sh
keytool -import -alias oracledb-free -trustcacerts -keystore "/usr/java/jdk-11.0.15/lib/security/cacerts" -file /secrets/ca.crt -storepass changeit -noprompt
keytool -list -keystore /usr/java/jdk-11.0.15/lib/security/cacerts -storepass changeit | egrep oracledb-free

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

# The version of Istio to deploy
VERSION=1.18.7
# Import all Istio dashboards
for DASHBOARD in 7639 11829 7636 7630 7645 13277; do
    REVISION="$(curl -s https://grafana.com/api/dashboards/${DASHBOARD}/revisions -s | jq ".items[] | select(.description | contains(\"${VERSION}\")) | .revision")"
    curl -s https://grafana.com/api/dashboards/${DASHBOARD}/revisions/${REVISION}/download > /tmp/dashboard.json
    
    TITLE=$(echo "$(cat /tmp/dashboard.json | jq -r '.title')" | sed 'y/ /-/' | sed -e 's/\(.*\)/\L\1/')
    echo "Importing ${TITLE} (revision ${REVISION}, id ${DASHBOARD})..."
    cp /tmp/dashboard.json ./helm/grafana/dashboards/import/"${TITLE}".json
done

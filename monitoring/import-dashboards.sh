#!/bin/bash
set -e

DASHBOARD_DIR="/Users/kakf/Projects/Zea.Task/monitoring/dashboards"
mkdir -p "$DASHBOARD_DIR"

GRAFANA_URL=$(kubectl get svc prometheus-stack-grafana -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

GRAFANA_PASSWORD=$(kubectl get secret --namespace monitoring prometheus-stack-grafana -o jsonpath="{.data.admin-password}" | base64 --decode 2>/dev/null || echo "StrongPassword123!")

for dashboard in "$DASHBOARD_DIR"/*.json; do
  DASHBOARD_TITLE=$(grep -o '"title": "[^"]*"' "$dashboard" | head -1 | cut -d'"' -f4)
  DASHBOARD_UID=$(grep -o '"uid": "[^"]*"' "$dashboard" | head -1 | cut -d'"' -f4)

  echo "Importowanie dashboardu: $dashboard"
  echo "  - Tytuł: $DASHBOARD_TITLE"
  echo "  - UID: $DASHBOARD_UID"
  echo "  - URL: http://$GRAFANA_URL/d/$DASHBOARD_UID"


  TEMP_FILE=$(mktemp)
  {
    echo '{"dashboard":'
    cat "$dashboard" | sed 's/"id": [0-9]*,/"id": null,/' | sed 's/"version": [0-9]*/"version": null/'
    echo ', "overwrite": true, "folderId": 0, "message": "Imported via script"}'
  } > "$TEMP_FILE"

  RESPONSE=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -H "Authorization: Basic $(echo -n admin:$GRAFANA_PASSWORD | base64)" \
    "http://$GRAFANA_URL/api/dashboards/db" \
    -d @"$TEMP_FILE")
  
  if echo "$RESPONSE" | grep -q "success"; then
    echo " - Zaimportowano pomyślnie!"
  else
    echo " - Błąd importu: $RESPONSE"
  fi

  rm "$TEMP_FILE"
done


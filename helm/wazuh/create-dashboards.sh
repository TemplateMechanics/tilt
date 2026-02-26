#!/bin/bash
# Provision OpenSearch index patterns, visualizations, and dashboards for Wazuh.
# Runs automatically via a Kubernetes Job after dashboard starts, or manually:
#   cat helm/wazuh/create-dashboards.sh | kubectl exec -n wazuh -i deployment/wazuh-dashboard -- bash

DASHBOARD_URL="${DASHBOARD_URL:-http://wazuh-dashboard:5601}"
OSD_HEADER="osd-xsrf: true"

###############################################################################
# Wait for dashboard API to be ready
###############################################################################
echo "=== Waiting for Wazuh Dashboard to be ready ==="
for i in $(seq 1 60); do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" "${DASHBOARD_URL}/api/status" 2>/dev/null)
  if [ "$STATUS" = "200" ]; then
    echo "  Dashboard API is ready"
    break
  fi
  echo "  Attempt $i/60 - status $STATUS, retrying in 5s..."
  sleep 5
done
if [ "$STATUS" != "200" ]; then
  echo "ERROR: Dashboard did not become ready in time"
  exit 1
fi

# Helper function to create a saved object
create_saved_object() {
  local type="$1"
  local id="$2"
  local body="$3"
  curl -s -X POST "${DASHBOARD_URL}/api/saved_objects/${type}/${id}?overwrite=true" \
    -H "Content-Type: application/json" \
    -H "${OSD_HEADER}" \
    -d "${body}" > /dev/null 2>&1
  echo "  Created ${type}: ${id}"
}

###############################################################################
# INDEX PATTERNS
###############################################################################
echo "=== Creating Index Patterns ==="

for pattern in "filebeat-*" "filebeat-kubernetes-*" "filebeat-backstage-*" \
               "filebeat-prometheus-*" "filebeat-flux-*" "filebeat-crossplane-*" \
               "filebeat-kube-system-*" "filebeat-traefik-*" "filebeat-falco-*" \
               "filebeat-trivy-*" "wazuh-alerts-*"; do
  create_saved_object "index-pattern" "${pattern}" \
    "{\"attributes\":{\"title\":\"${pattern}\",\"timeFieldName\":\"@timestamp\"}}"
done

###############################################################################
# VISUALIZATIONS - Log Volume Over Time (per source)
###############################################################################
echo "=== Creating Visualizations ==="

for source in kubernetes kube-system backstage prometheus flux crossplane; do
  title_name=$(echo "$source" | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2))}1')

  vis_state=$(cat <<VISEOF
{"title":"${title_name} - Log Volume","type":"area","params":{"type":"area","grid":{"categoryLines":false},"categoryAxes":[{"id":"CategoryAxis-1","type":"category","position":"bottom","show":true,"style":{},"scale":{"type":"linear"},"labels":{"show":true,"filter":true,"truncate":100},"title":{}}],"valueAxes":[{"id":"ValueAxis-1","name":"LeftAxis-1","type":"value","position":"left","show":true,"style":{},"scale":{"type":"linear","mode":"normal"},"labels":{"show":true,"rotate":0,"filter":false,"truncate":100},"title":{"text":"Log Count"}}],"seriesParams":[{"show":true,"type":"area","mode":"stacked","data":{"label":"Count","id":"1"},"valueAxis":"ValueAxis-1","drawLinesBetweenPoints":true,"lineWidth":2,"showCircles":false}],"addTooltip":true,"addLegend":true,"legendPosition":"right","times":[],"addTimeMarker":false},"aggs":[{"id":"1","enabled":true,"type":"count","schema":"metric","params":{}},{"id":"2","enabled":true,"type":"date_histogram","schema":"segment","params":{"field":"@timestamp","useNormalizedOpenSearchInterval":true,"scaleMetricValues":false,"interval":"auto","drop_partials":false,"min_doc_count":1,"extended_bounds":{}}}]}
VISEOF
)

  search_source='{"query":{"query":"","language":"kuery"},"filter":[],"indexRefName":"kibanaSavedObjectMeta.searchSourceJSON.index"}'
  refs="[{\"name\":\"kibanaSavedObjectMeta.searchSourceJSON.index\",\"type\":\"index-pattern\",\"id\":\"filebeat-${source}-*\"}]"

  body=$(cat <<EOF
{"attributes":{"title":"${title_name} - Log Volume","visState":"$(echo "$vis_state" | sed 's/"/\\"/g')","uiStateJSON":"{}","description":"Log volume over time for ${title_name}","kibanaSavedObjectMeta":{"searchSourceJSON":"$(echo "$search_source" | sed 's/"/\\"/g')"}},"references":$(echo "$refs")}
EOF
)
  create_saved_object "visualization" "vis-${source}-log-volume" "$body"
done

###############################################################################
# VISUALIZATION - All Sources Combined Log Volume (stacked area)
###############################################################################

vis_state_all='{"title":"All Sources - Log Volume","type":"area","params":{"type":"area","grid":{"categoryLines":false},"categoryAxes":[{"id":"CategoryAxis-1","type":"category","position":"bottom","show":true,"style":{},"scale":{"type":"linear"},"labels":{"show":true,"filter":true,"truncate":100},"title":{}}],"valueAxes":[{"id":"ValueAxis-1","name":"LeftAxis-1","type":"value","position":"left","show":true,"style":{},"scale":{"type":"linear","mode":"normal"},"labels":{"show":true,"rotate":0,"filter":false,"truncate":100},"title":{"text":"Log Count"}}],"seriesParams":[{"show":true,"type":"area","mode":"stacked","data":{"label":"Count","id":"1"},"valueAxis":"ValueAxis-1","drawLinesBetweenPoints":true,"lineWidth":2,"showCircles":false}],"addTooltip":true,"addLegend":true,"legendPosition":"right","times":[],"addTimeMarker":false},"aggs":[{"id":"1","enabled":true,"type":"count","schema":"metric","params":{}},{"id":"2","enabled":true,"type":"date_histogram","schema":"segment","params":{"field":"@timestamp","useNormalizedOpenSearchInterval":true,"scaleMetricValues":false,"interval":"auto","drop_partials":false,"min_doc_count":1,"extended_bounds":{}}},{"id":"3","enabled":true,"type":"terms","schema":"group","params":{"field":"_index","orderBy":"1","order":"desc","size":10,"otherBucket":true,"otherBucketLabel":"Other","missingBucket":false}}]}'

search_source_all='{"query":{"query":"","language":"kuery"},"filter":[],"indexRefName":"kibanaSavedObjectMeta.searchSourceJSON.index"}'
refs_all='[{"name":"kibanaSavedObjectMeta.searchSourceJSON.index","type":"index-pattern","id":"filebeat-*"}]'

body_all="{\"attributes\":{\"title\":\"All Sources - Log Volume\",\"visState\":\"$(echo "$vis_state_all" | sed 's/"/\\"/g')\",\"uiStateJSON\":\"{}\",\"description\":\"Combined log volume from all filebeat sources\",\"kibanaSavedObjectMeta\":{\"searchSourceJSON\":\"$(echo "$search_source_all" | sed 's/"/\\"/g')\"}},\"references\":${refs_all}}"
create_saved_object "visualization" "vis-all-log-volume" "$body_all"

###############################################################################
# VISUALIZATION - Kubernetes Logs by Namespace (pie chart)
###############################################################################

vis_state_ns='{"title":"Kubernetes - Logs by Namespace","type":"pie","params":{"type":"pie","addTooltip":true,"addLegend":true,"legendPosition":"right","isDonut":true,"labels":{"show":true,"values":true,"last_level":true,"truncate":100}},"aggs":[{"id":"1","enabled":true,"type":"count","schema":"metric","params":{}},{"id":"2","enabled":true,"type":"terms","schema":"segment","params":{"field":"kubernetes.namespace_name","orderBy":"1","order":"desc","size":15,"otherBucket":true,"otherBucketLabel":"Other","missingBucket":false}}]}'

search_source_ns='{"query":{"query":"","language":"kuery"},"filter":[],"indexRefName":"kibanaSavedObjectMeta.searchSourceJSON.index"}'
refs_ns='[{"name":"kibanaSavedObjectMeta.searchSourceJSON.index","type":"index-pattern","id":"filebeat-kubernetes-*"}]'

body_ns="{\"attributes\":{\"title\":\"Kubernetes - Logs by Namespace\",\"visState\":\"$(echo "$vis_state_ns" | sed 's/"/\\"/g')\",\"uiStateJSON\":\"{}\",\"description\":\"Log distribution by Kubernetes namespace\",\"kibanaSavedObjectMeta\":{\"searchSourceJSON\":\"$(echo "$search_source_ns" | sed 's/"/\\"/g')\"}},\"references\":${refs_ns}}"
create_saved_object "visualization" "vis-k8s-by-namespace" "$body_ns"

###############################################################################
# VISUALIZATION - Kubernetes Logs by Container (horizontal bar)
###############################################################################

vis_state_ctr='{"title":"Kubernetes - Top Containers","type":"horizontal_bar","params":{"type":"horizontal_bar","grid":{"categoryLines":false},"categoryAxes":[{"id":"CategoryAxis-1","type":"category","position":"left","show":true,"style":{},"scale":{"type":"linear"},"labels":{"show":true,"filter":true,"truncate":200},"title":{}}],"valueAxes":[{"id":"ValueAxis-1","name":"BottomAxis-1","type":"value","position":"bottom","show":true,"style":{},"scale":{"type":"linear","mode":"normal"},"labels":{"show":true,"rotate":0,"filter":false,"truncate":100},"title":{"text":"Count"}}],"seriesParams":[{"show":true,"type":"histogram","mode":"stacked","data":{"label":"Count","id":"1"},"valueAxis":"ValueAxis-1","drawLinesBetweenPoints":true,"lineWidth":2,"showCircles":true}],"addTooltip":true,"addLegend":true,"legendPosition":"right","times":[],"addTimeMarker":false},"aggs":[{"id":"1","enabled":true,"type":"count","schema":"metric","params":{}},{"id":"2","enabled":true,"type":"terms","schema":"segment","params":{"field":"kubernetes.container.name","orderBy":"1","order":"desc","size":15,"otherBucket":true,"otherBucketLabel":"Other","missingBucket":false}}]}'

search_source_ctr='{"query":{"query":"","language":"kuery"},"filter":[],"indexRefName":"kibanaSavedObjectMeta.searchSourceJSON.index"}'
refs_ctr='[{"name":"kibanaSavedObjectMeta.searchSourceJSON.index","type":"index-pattern","id":"filebeat-kubernetes-*"}]'

body_ctr="{\"attributes\":{\"title\":\"Kubernetes - Top Containers\",\"visState\":\"$(echo "$vis_state_ctr" | sed 's/"/\\"/g')\",\"uiStateJSON\":\"{}\",\"description\":\"Top containers by log volume\",\"kibanaSavedObjectMeta\":{\"searchSourceJSON\":\"$(echo "$search_source_ctr" | sed 's/"/\\"/g')\"}},\"references\":${refs_ctr}}"
create_saved_object "visualization" "vis-k8s-top-containers" "$body_ctr"

###############################################################################
# VISUALIZATION - Stream distribution (stdout vs stderr) for kubernetes
###############################################################################

vis_state_stream='{"title":"Kubernetes - stdout vs stderr","type":"pie","params":{"type":"pie","addTooltip":true,"addLegend":true,"legendPosition":"right","isDonut":true,"labels":{"show":true,"values":true,"last_level":true,"truncate":100}},"aggs":[{"id":"1","enabled":true,"type":"count","schema":"metric","params":{}},{"id":"2","enabled":true,"type":"terms","schema":"segment","params":{"field":"stream","orderBy":"1","order":"desc","size":5,"otherBucket":false,"missingBucket":false}}]}'

search_source_stream='{"query":{"query":"","language":"kuery"},"filter":[],"indexRefName":"kibanaSavedObjectMeta.searchSourceJSON.index"}'
refs_stream='[{"name":"kibanaSavedObjectMeta.searchSourceJSON.index","type":"index-pattern","id":"filebeat-kubernetes-*"}]'

body_stream="{\"attributes\":{\"title\":\"Kubernetes - stdout vs stderr\",\"visState\":\"$(echo "$vis_state_stream" | sed 's/"/\\"/g')\",\"uiStateJSON\":\"{}\",\"description\":\"Distribution of stdout vs stderr logs\",\"kibanaSavedObjectMeta\":{\"searchSourceJSON\":\"$(echo "$search_source_stream" | sed 's/"/\\"/g')\"}},\"references\":${refs_stream}}"
create_saved_object "visualization" "vis-k8s-stream" "$body_stream"

###############################################################################
# VISUALIZATION - Kube System Top Pods
###############################################################################

vis_state_kspod='{"title":"Kube System - Top Pods","type":"horizontal_bar","params":{"type":"horizontal_bar","grid":{"categoryLines":false},"categoryAxes":[{"id":"CategoryAxis-1","type":"category","position":"left","show":true,"style":{},"scale":{"type":"linear"},"labels":{"show":true,"filter":true,"truncate":200},"title":{}}],"valueAxes":[{"id":"ValueAxis-1","name":"BottomAxis-1","type":"value","position":"bottom","show":true,"style":{},"scale":{"type":"linear","mode":"normal"},"labels":{"show":true,"rotate":0,"filter":false,"truncate":100},"title":{"text":"Count"}}],"seriesParams":[{"show":true,"type":"histogram","mode":"stacked","data":{"label":"Count","id":"1"},"valueAxis":"ValueAxis-1","drawLinesBetweenPoints":true,"lineWidth":2,"showCircles":true}],"addTooltip":true,"addLegend":true,"legendPosition":"right","times":[],"addTimeMarker":false},"aggs":[{"id":"1","enabled":true,"type":"count","schema":"metric","params":{}},{"id":"2","enabled":true,"type":"terms","schema":"segment","params":{"field":"kubernetes.pod.name","orderBy":"1","order":"desc","size":15,"otherBucket":true,"otherBucketLabel":"Other","missingBucket":false}}]}'

search_source_kspod='{"query":{"query":"","language":"kuery"},"filter":[],"indexRefName":"kibanaSavedObjectMeta.searchSourceJSON.index"}'
refs_kspod='[{"name":"kibanaSavedObjectMeta.searchSourceJSON.index","type":"index-pattern","id":"filebeat-kube-system-*"}]'

body_kspod="{\"attributes\":{\"title\":\"Kube System - Top Pods\",\"visState\":\"$(echo "$vis_state_kspod" | sed 's/"/\\"/g')\",\"uiStateJSON\":\"{}\",\"description\":\"Top pods by log volume in kube-system\",\"kibanaSavedObjectMeta\":{\"searchSourceJSON\":\"$(echo "$search_source_kspod" | sed 's/"/\\"/g')\"}},\"references\":${refs_kspod}}"
create_saved_object "visualization" "vis-ks-top-pods" "$body_kspod"

###############################################################################
# VISUALIZATION - Metric counts per source
###############################################################################

for source in kubernetes kube-system backstage prometheus flux crossplane; do
  title_name=$(echo "$source" | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2))}1')

  vis_state_metric="{\"title\":\"${title_name} - Total Logs\",\"type\":\"metric\",\"params\":{\"addTooltip\":true,\"addLegend\":false,\"type\":\"metric\",\"metric\":{\"percentageMode\":false,\"useRanges\":false,\"colorSchema\":\"Green to Red\",\"metricColorMode\":\"None\",\"colorsRange\":[{\"from\":0,\"to\":10000}],\"labels\":{\"show\":true},\"invertColors\":false,\"style\":{\"bgFill\":\"#000\",\"bgColor\":false,\"labelColor\":false,\"subText\":\"\",\"fontSize\":40}}},\"aggs\":[{\"id\":\"1\",\"enabled\":true,\"type\":\"count\",\"schema\":\"metric\",\"params\":{}}]}"

  search_source_metric='{"query":{"query":"","language":"kuery"},"filter":[],"indexRefName":"kibanaSavedObjectMeta.searchSourceJSON.index"}'
  refs_metric="[{\"name\":\"kibanaSavedObjectMeta.searchSourceJSON.index\",\"type\":\"index-pattern\",\"id\":\"filebeat-${source}-*\"}]"

  body_metric="{\"attributes\":{\"title\":\"${title_name} - Total Logs\",\"visState\":\"$(echo "$vis_state_metric" | sed 's/"/\\"/g')\",\"uiStateJSON\":\"{}\",\"description\":\"Total log count for ${title_name}\",\"kibanaSavedObjectMeta\":{\"searchSourceJSON\":\"$(echo "$search_source_metric" | sed 's/"/\\"/g')\"}},\"references\":${refs_metric}}"
  create_saved_object "visualization" "vis-${source}-metric" "$body_metric"
done

###############################################################################
# VISUALIZATION - Markdown header for Infrastructure Overview
###############################################################################

vis_state_header='{"title":"Infrastructure Monitoring Header","type":"markdown","params":{"fontSize":12,"openLinksInNewTab":false,"markdown":"# Infrastructure Log Monitoring\n\nThis dashboard shows log data collected by Filebeat from across the Kubernetes cluster.\n\n**Sources:** Kubernetes pods, kube-system, Backstage, Prometheus, Flux CD, Crossplane"},"aggs":[]}'

body_header="{\"attributes\":{\"title\":\"Infrastructure Monitoring Header\",\"visState\":\"$(echo "$vis_state_header" | sed 's/"/\\"/g')\",\"uiStateJSON\":\"{}\",\"description\":\"\",\"kibanaSavedObjectMeta\":{\"searchSourceJSON\":\"{\\\"query\\\":{\\\"query\\\":\\\"\\\",\\\"language\\\":\\\"kuery\\\"},\\\"filter\\\":[]}\"}},\"references\":[]}"
create_saved_object "visualization" "vis-infra-header" "$body_header"

###############################################################################
# VISUALIZATION - Markdown header for Kubernetes dashboard
###############################################################################

vis_state_k8s_header='{"title":"Kubernetes Logs Header","type":"markdown","params":{"fontSize":12,"openLinksInNewTab":false,"markdown":"# Kubernetes Logs\n\nContainer logs collected from all namespaces (excluding kube-system which has its own dashboard)."},"aggs":[]}'

body_k8s_header="{\"attributes\":{\"title\":\"Kubernetes Logs Header\",\"visState\":\"$(echo "$vis_state_k8s_header" | sed 's/"/\\"/g')\",\"uiStateJSON\":\"{}\",\"description\":\"\",\"kibanaSavedObjectMeta\":{\"searchSourceJSON\":\"{\\\"query\\\":{\\\"query\\\":\\\"\\\",\\\"language\\\":\\\"kuery\\\"},\\\"filter\\\":[]}\"}},\"references\":[]}"
create_saved_object "visualization" "vis-k8s-header" "$body_k8s_header"

echo ""
echo "=== Creating Dashboards ==="

###############################################################################
# DASHBOARD - Infrastructure Overview
###############################################################################

panels_infra='[
  {"version":"2.13.0","gridData":{"x":0,"y":0,"w":48,"h":4,"i":"1"},"panelIndex":"1","embeddableConfig":{},"panelRefName":"panel_0"},
  {"version":"2.13.0","gridData":{"x":0,"y":4,"w":8,"h":6,"i":"2"},"panelIndex":"2","embeddableConfig":{},"panelRefName":"panel_1"},
  {"version":"2.13.0","gridData":{"x":8,"y":4,"w":8,"h":6,"i":"3"},"panelIndex":"3","embeddableConfig":{},"panelRefName":"panel_2"},
  {"version":"2.13.0","gridData":{"x":16,"y":4,"w":8,"h":6,"i":"4"},"panelIndex":"4","embeddableConfig":{},"panelRefName":"panel_3"},
  {"version":"2.13.0","gridData":{"x":24,"y":4,"w":8,"h":6,"i":"5"},"panelIndex":"5","embeddableConfig":{},"panelRefName":"panel_4"},
  {"version":"2.13.0","gridData":{"x":32,"y":4,"w":8,"h":6,"i":"6"},"panelIndex":"6","embeddableConfig":{},"panelRefName":"panel_5"},
  {"version":"2.13.0","gridData":{"x":40,"y":4,"w":8,"h":6,"i":"7"},"panelIndex":"7","embeddableConfig":{},"panelRefName":"panel_6"},
  {"version":"2.13.0","gridData":{"x":0,"y":10,"w":48,"h":14,"i":"8"},"panelIndex":"8","embeddableConfig":{},"panelRefName":"panel_7"}
]'

refs_infra='[
  {"name":"panel_0","type":"visualization","id":"vis-infra-header"},
  {"name":"panel_1","type":"visualization","id":"vis-kubernetes-metric"},
  {"name":"panel_2","type":"visualization","id":"vis-kube-system-metric"},
  {"name":"panel_3","type":"visualization","id":"vis-backstage-metric"},
  {"name":"panel_4","type":"visualization","id":"vis-prometheus-metric"},
  {"name":"panel_5","type":"visualization","id":"vis-flux-metric"},
  {"name":"panel_6","type":"visualization","id":"vis-crossplane-metric"},
  {"name":"panel_7","type":"visualization","id":"vis-all-log-volume"}
]'

body_infra="{\"attributes\":{\"title\":\"Infrastructure Overview\",\"hits\":0,\"description\":\"Overview of all infrastructure log sources collected by Filebeat\",\"panelsJSON\":\"$(echo "$panels_infra" | tr -d '\n' | sed 's/"/\\"/g')\",\"optionsJSON\":\"{\\\"hidePanelTitles\\\":false,\\\"useMargins\\\":true}\",\"kibanaSavedObjectMeta\":{\"searchSourceJSON\":\"{\\\"query\\\":{\\\"query\\\":\\\"\\\",\\\"language\\\":\\\"kuery\\\"},\\\"filter\\\":[]}\"}},\"references\":$(echo "$refs_infra" | tr -d '\n')}"
create_saved_object "dashboard" "dashboard-infra-overview" "$body_infra"

###############################################################################
# DASHBOARD - Kubernetes Logs
###############################################################################

panels_k8s='[
  {"version":"2.13.0","gridData":{"x":0,"y":0,"w":48,"h":3,"i":"1"},"panelIndex":"1","embeddableConfig":{},"panelRefName":"panel_0"},
  {"version":"2.13.0","gridData":{"x":0,"y":3,"w":48,"h":14,"i":"2"},"panelIndex":"2","embeddableConfig":{},"panelRefName":"panel_1"},
  {"version":"2.13.0","gridData":{"x":0,"y":17,"w":16,"h":12,"i":"3"},"panelIndex":"3","embeddableConfig":{},"panelRefName":"panel_2"},
  {"version":"2.13.0","gridData":{"x":16,"y":17,"w":16,"h":12,"i":"4"},"panelIndex":"4","embeddableConfig":{},"panelRefName":"panel_3"},
  {"version":"2.13.0","gridData":{"x":32,"y":17,"w":16,"h":12,"i":"5"},"panelIndex":"5","embeddableConfig":{},"panelRefName":"panel_4"}
]'

refs_k8s='[
  {"name":"panel_0","type":"visualization","id":"vis-k8s-header"},
  {"name":"panel_1","type":"visualization","id":"vis-kubernetes-log-volume"},
  {"name":"panel_2","type":"visualization","id":"vis-k8s-by-namespace"},
  {"name":"panel_3","type":"visualization","id":"vis-k8s-top-containers"},
  {"name":"panel_4","type":"visualization","id":"vis-k8s-stream"}
]'

body_k8s="{\"attributes\":{\"title\":\"Kubernetes Logs\",\"hits\":0,\"description\":\"Kubernetes pod logs by namespace, container and stream\",\"panelsJSON\":\"$(echo "$panels_k8s" | tr -d '\n' | sed 's/"/\\"/g')\",\"optionsJSON\":\"{\\\"hidePanelTitles\\\":false,\\\"useMargins\\\":true}\",\"kibanaSavedObjectMeta\":{\"searchSourceJSON\":\"{\\\"query\\\":{\\\"query\\\":\\\"\\\",\\\"language\\\":\\\"kuery\\\"},\\\"filter\\\":[]}\"}},\"references\":$(echo "$refs_k8s" | tr -d '\n')}"
create_saved_object "dashboard" "dashboard-kubernetes" "$body_k8s"

###############################################################################
# DASHBOARD - Kube System
###############################################################################

panels_ks='[
  {"version":"2.13.0","gridData":{"x":0,"y":0,"w":48,"h":14,"i":"1"},"panelIndex":"1","embeddableConfig":{},"panelRefName":"panel_0"},
  {"version":"2.13.0","gridData":{"x":0,"y":14,"w":48,"h":14,"i":"2"},"panelIndex":"2","embeddableConfig":{},"panelRefName":"panel_1"}
]'

refs_ks='[
  {"name":"panel_0","type":"visualization","id":"vis-kube-system-log-volume"},
  {"name":"panel_1","type":"visualization","id":"vis-ks-top-pods"}
]'

body_ks="{\"attributes\":{\"title\":\"Kube System Logs\",\"hits\":0,\"description\":\"Logs from kube-system namespace components\",\"panelsJSON\":\"$(echo "$panels_ks" | tr -d '\n' | sed 's/"/\\"/g')\",\"optionsJSON\":\"{\\\"hidePanelTitles\\\":false,\\\"useMargins\\\":true}\",\"kibanaSavedObjectMeta\":{\"searchSourceJSON\":\"{\\\"query\\\":{\\\"query\\\":\\\"\\\",\\\"language\\\":\\\"kuery\\\"},\\\"filter\\\":[]}\"}},\"references\":$(echo "$refs_ks" | tr -d '\n')}"
create_saved_object "dashboard" "dashboard-kube-system" "$body_ks"

###############################################################################
# DASHBOARD - Backstage
###############################################################################

panels_bs='[
  {"version":"2.13.0","gridData":{"x":0,"y":0,"w":12,"h":8,"i":"1"},"panelIndex":"1","embeddableConfig":{},"panelRefName":"panel_0"},
  {"version":"2.13.0","gridData":{"x":12,"y":0,"w":36,"h":14,"i":"2"},"panelIndex":"2","embeddableConfig":{},"panelRefName":"panel_1"}
]'

refs_bs='[
  {"name":"panel_0","type":"visualization","id":"vis-backstage-metric"},
  {"name":"panel_1","type":"visualization","id":"vis-backstage-log-volume"}
]'

body_bs="{\"attributes\":{\"title\":\"Backstage Logs\",\"hits\":0,\"description\":\"Backstage application logs\",\"panelsJSON\":\"$(echo "$panels_bs" | tr -d '\n' | sed 's/"/\\"/g')\",\"optionsJSON\":\"{\\\"hidePanelTitles\\\":false,\\\"useMargins\\\":true}\",\"kibanaSavedObjectMeta\":{\"searchSourceJSON\":\"{\\\"query\\\":{\\\"query\\\":\\\"\\\",\\\"language\\\":\\\"kuery\\\"},\\\"filter\\\":[]}\"}},\"references\":$(echo "$refs_bs" | tr -d '\n')}"
create_saved_object "dashboard" "dashboard-backstage" "$body_bs"

###############################################################################
# DASHBOARD - Prometheus
###############################################################################

panels_prom='[
  {"version":"2.13.0","gridData":{"x":0,"y":0,"w":12,"h":8,"i":"1"},"panelIndex":"1","embeddableConfig":{},"panelRefName":"panel_0"},
  {"version":"2.13.0","gridData":{"x":12,"y":0,"w":36,"h":14,"i":"2"},"panelIndex":"2","embeddableConfig":{},"panelRefName":"panel_1"}
]'

refs_prom='[
  {"name":"panel_0","type":"visualization","id":"vis-prometheus-metric"},
  {"name":"panel_1","type":"visualization","id":"vis-prometheus-log-volume"}
]'

body_prom="{\"attributes\":{\"title\":\"Prometheus Logs\",\"hits\":0,\"description\":\"Prometheus server logs\",\"panelsJSON\":\"$(echo "$panels_prom" | tr -d '\n' | sed 's/"/\\"/g')\",\"optionsJSON\":\"{\\\"hidePanelTitles\\\":false,\\\"useMargins\\\":true}\",\"kibanaSavedObjectMeta\":{\"searchSourceJSON\":\"{\\\"query\\\":{\\\"query\\\":\\\"\\\",\\\"language\\\":\\\"kuery\\\"},\\\"filter\\\":[]}\"}},\"references\":$(echo "$refs_prom" | tr -d '\n')}"
create_saved_object "dashboard" "dashboard-prometheus" "$body_prom"

###############################################################################
# DASHBOARD - Flux CD
###############################################################################

panels_flux='[
  {"version":"2.13.0","gridData":{"x":0,"y":0,"w":12,"h":8,"i":"1"},"panelIndex":"1","embeddableConfig":{},"panelRefName":"panel_0"},
  {"version":"2.13.0","gridData":{"x":12,"y":0,"w":36,"h":14,"i":"2"},"panelIndex":"2","embeddableConfig":{},"panelRefName":"panel_1"}
]'

refs_flux='[
  {"name":"panel_0","type":"visualization","id":"vis-flux-metric"},
  {"name":"panel_1","type":"visualization","id":"vis-flux-log-volume"}
]'

body_flux="{\"attributes\":{\"title\":\"Flux CD Logs\",\"hits\":0,\"description\":\"Flux CD GitOps controller logs\",\"panelsJSON\":\"$(echo "$panels_flux" | tr -d '\n' | sed 's/"/\\"/g')\",\"optionsJSON\":\"{\\\"hidePanelTitles\\\":false,\\\"useMargins\\\":true}\",\"kibanaSavedObjectMeta\":{\"searchSourceJSON\":\"{\\\"query\\\":{\\\"query\\\":\\\"\\\",\\\"language\\\":\\\"kuery\\\"},\\\"filter\\\":[]}\"}},\"references\":$(echo "$refs_flux" | tr -d '\n')}"
create_saved_object "dashboard" "dashboard-flux" "$body_flux"

###############################################################################
# DASHBOARD - Crossplane
###############################################################################

panels_cp='[
  {"version":"2.13.0","gridData":{"x":0,"y":0,"w":12,"h":8,"i":"1"},"panelIndex":"1","embeddableConfig":{},"panelRefName":"panel_0"},
  {"version":"2.13.0","gridData":{"x":12,"y":0,"w":36,"h":14,"i":"2"},"panelIndex":"2","embeddableConfig":{},"panelRefName":"panel_1"}
]'

refs_cp='[
  {"name":"panel_0","type":"visualization","id":"vis-crossplane-metric"},
  {"name":"panel_1","type":"visualization","id":"vis-crossplane-log-volume"}
]'

body_cp="{\"attributes\":{\"title\":\"Crossplane Logs\",\"hits\":0,\"description\":\"Crossplane provider and controller logs\",\"panelsJSON\":\"$(echo "$panels_cp" | tr -d '\n' | sed 's/"/\\"/g')\",\"optionsJSON\":\"{\\\"hidePanelTitles\\\":false,\\\"useMargins\\\":true}\",\"kibanaSavedObjectMeta\":{\"searchSourceJSON\":\"{\\\"query\\\":{\\\"query\\\":\\\"\\\",\\\"language\\\":\\\"kuery\\\"},\\\"filter\\\":[]}\"}},\"references\":$(echo "$refs_cp" | tr -d '\n')}"
create_saved_object "dashboard" "dashboard-crossplane" "$body_cp"

echo ""
echo "=== Done! ==="
echo "Created dashboards:"
echo "  - Infrastructure Overview (combined metrics + log volume)"
echo "  - Kubernetes Logs (volume, namespace, containers, streams)"
echo "  - Kube System Logs (volume, top pods)"
echo "  - Backstage Logs"
echo "  - Prometheus Logs"
echo "  - Flux CD Logs"
echo "  - Crossplane Logs"
echo ""
echo "Navigate to: Menu > OpenSearch Dashboards > Dashboard"

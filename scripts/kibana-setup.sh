#!/bin/bash

echo "Waiting for Kibana..."
kibana_timeout=0

until curl -sf http://localhost/kibana/api/status | grep -q '"level":"available"'; do
    sleep 5
    if [ "$kibana_timeout" -lt 24 ]; then
        ((kibana_timeout += 1))
    else
        echo "Kibana didn't start in time"
        exit 1
    fi
done

for view in \
    'nginx-logs-view:nginx-logs-*:Nginx Logs' \
    'apps-logs-view:apps-logs-*:Apps Logs'
do
    id="${view%%:*}"
    rest="${view#*:}"
    pattern="${rest%%:*}"
    name="${rest##*:}"

    curl -sf -X POST "http://localhost/kibana/api/data_views/data_view" \
        -H "kbn-xsrf: true" \
        -H "Content-Type: application/json" \
        -d "{\"data_view\":{\"id\":\"${id}\",\"title\":\"${pattern}\",\"name\":\"${name}\",\"timeFieldName\":\"@timestamp\"},\"override\":true}" &> /dev/null
done

echo "Kibana configured successfully"

#!/bin/bash

ES_URL="http://localhost:9200"

echo "[es] Waiting for Elasticsearch..."
timeout=0

until curl -sf "${ES_URL}/_cluster/health" | grep -qE '"status":"(green|yellow)"'; do
    sleep 3
    if [ "$timeout" -lt 24 ]; then
        ((timeout += 1))
    else
        echo "[es] Elasticsearch didn't start in time"
        exit 1
    fi
done
echo "[es] Elasticsearch is up."

echo "[es] Applying index template..."
curl -sf -X PUT "${ES_URL}/_index_template/poly-ci-logs" \
  -H "Content-Type: application/json" \
  -d '{
    "index_patterns": ["nginx-logs-*", "apps-logs-*"],
    "template": {
      "settings": {
        "number_of_shards": 1,
        "number_of_replicas": 0
      },
      "mappings": {
        "properties": {
          "@timestamp":     { "type": "date" },
          "container.name": { "type": "keyword" },
          "nginx.status":   { "type": "integer" },
          "nginx.bytes":    { "type": "integer" },
          "nginx.method":   { "type": "keyword" },
          "nginx.uri":      { "type": "keyword" },
          "nginx.ip":       { "type": "ip" }
        }
      }
    }
  }' &>dev/null && echo "[es] Template applied." || echo "[es] Template apply failed."

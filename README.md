# Monitoring Stack

Full-featured logging and monitoring stack built on **ELK Stack** (Elasticsearch, Logstash, Kibana) with Nginx reverse proxy and Python application.

## 🏗️ Architecture

### Components

```
┌─────────────────────────────────────────────────────────────┐
│                      External Traffic (Port 80)              │
└──────────────────────┬──────────────────────────────────────┘
                       │
                ┌──────▼──────┐
                │    Nginx    │  Reverse Proxy
                └──────┬──────┘
                       │
         ┌─────────────┴──────────────┐
         │                            │
    ┌────▼────┐                 ┌────▼──────┐
    │ Python  │                 │   Kibana  │
    │   App   │ (8080)          │  (5601)   │
    └────┬────┘                 └────┬──────┘
         │                            │
         └─────────────┬──────────────┘
                       │
          ┌────────────┴────────────┐
          │   Logging Network       │
          └────────────┬────────────┘
                       │
      ┌────────────────┼────────────────┐
      │                │                │
  ┌───▼───┐      ┌─────▼─────┐    ┌───▼────┐
  │FileBeat│     │  Logstash │    │Elastic │
  │(collect)     │ (filter)  │    │search  │
  └────────┘     └───────────┘    └────────┘
```

### Services

| Service | Image | Port | Purpose |
|---------|-------|------|----------|
| **nginx** | nginx:alpine | 80 | Reverse proxy, load balancing |
| **python-app** | tsuyakashi/poly-ci:python-latest | 8080 | Application workload |
| **filebeat** | filebeat:8.19.17 | - | Log collection from Docker containers |
| **logstash** | logstash:8.19.17 | 5044 | Log processing and filtering |
| **elasticsearch** | elasticsearch:8.19.17 | 9200 | Log indexing and storage |
| **kibana** | kibana:8.19.17 | 5601 | Log visualization and analysis |

### Networks

- **web-network**: Nginx ↔ Python App
- **logging-network**: Filebeat → Logstash → Elasticsearch ← Kibana

## 🚀 Quick Start

### Prerequisites

- Docker & Docker Compose
- Root/sudo access
- ~3GB disk space for Elasticsearch data

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/tsuyakashi/monitoring-stack.git
   cd monitoring-stack
   ```

2. **Set environment variables** (optional, defaults provided)
   ```bash
   cp .env.example .env  # Create from template if exists
   # Edit .env and set ELASTIC_PASSWORD
   export ELASTIC_PASSWORD="your-secure-password"
   ```

3. **Start the stack**
   ```bash
   sudo ./index.sh
   ```

   This will:
   - Start all Docker containers
   - Initialize Elasticsearch
   - Configure Kibana
   - Wait for all services to be healthy

### Access Services

- **Python App**: http://localhost/python/
- **Kibana**: http://localhost/kibana/
- **Elasticsearch API**: http://localhost:9200/ (requires auth)

## 🔐 Security

### Elasticsearch Authentication

By default, Elasticsearch is configured with security enabled:

- **Username**: `elastic`
- **Password**: Set via `ELASTIC_PASSWORD` environment variable (default: `changeme`)

**⚠️ Important**: Change the default password in production!

```bash
export ELASTIC_PASSWORD="your-super-secure-password"
sudo ./index.sh
```

### Firewall Rules

```bash
# Restrict access to monitoring ports
sudo ufw allow 80/tcp    # Nginx only
sudo ufw deny 9200/tcp   # Block direct ES access
sudo ufw deny 5601/tcp   # Block direct Kibana access
```

## 📊 Log Processing

### Filebeat Collection

Filebeat automatically collects Docker logs from:
- All running containers
- Excludes: elasticsearch, logstash, kibana, filebeat (prevents loops)

**Configuration**: `monitoring/filebeat.yml`

### Logstash Filtering

Logs are processed and indexed based on source:

| Source | Index Pattern | Fields Parsed |
|--------|---------------|----------------|
| Nginx | `nginx-logs-YYYY.MM.dd` | status, bytes, method, uri, ip |
| Other apps | `apps-logs-YYYY.MM.dd` | Original JSON structure |
| Parse errors | `*-error-YYYY.MM.dd` | Raw message + error flag |

**Configuration**: `monitoring/logstash.conf`

## 🛠️ Configuration

### Nginx (`nginx/nginx.conf`)

- Reverse proxy for Python app (`/python/`)
- Kibana access via (`/kibana/`)
- JSON logging for better analysis
- Gzip compression enabled
- Health check endpoint (`/health`)

### Elasticsearch (`docker-compose.yml`)

- Single-node cluster
- Security: enabled
- Memory: 512m (JVM), 1GB container limit
- Disk watermarks:
  - Low: 85% (warn)
  - High: 90% (block writes)
  - Flood: 95% (critical)

### Resource Limits

All services have memory limits to prevent resource exhaustion:

```yaml
Deploy Limits:
  nginx: 256MB
  python-app: 512MB
  filebeat: 256MB
  logstash: 512MB
  elasticsearch: 1GB
  kibana: 512MB
```

## 🏥 Health Checks

All critical services include health checks:

- **Nginx**: Checks `/health` endpoint (40s start period)
- **Python App**: Checks `/health` endpoint (40s start period)
- **Elasticsearch**: HTTP health check (40s start period)
- **Logstash**: Checks monitoring API (40s start period)
- **Kibana**: Checks status API (60s start period)

## 📈 Monitoring & Troubleshooting

### View Stack Status

```bash
# Check all containers
docker compose ps

# Follow logs from all services
sudo docker compose logs -f

# Check specific service
sudo docker compose logs nginx
```

### Query Logs in Kibana

1. Open http://localhost/kibana/
2. Go to **Discover** → Select index pattern
3. Use KQL to filter:
   ```
   container.name: "nginx-proxy" AND nginx.status >= 500
   container.name: "python-app" AND parse_error: true
   ```

### Common Issues

#### Elasticsearch fails to start

```bash
# Check logs
sudo docker compose logs elasticsearch

# Common fix: Clear corrupted data
sudo docker compose down
sudo docker volume rm monitoring-stack_es-data
sudo ./index.sh
```

#### High disk usage

```bash
# Check ES status
curl -u elastic:$ELASTIC_PASSWORD http://localhost:9200/_cat/indices?v

# Delete old indices
curl -X DELETE -u elastic:$ELASTIC_PASSWORD http://localhost:9200/nginx-logs-2024.01.01
```

#### Memory issues

```bash
# Check resource usage
sudo docker stats

# Increase limits in docker-compose.yml
```

## 🧹 Maintenance

### Backup

```bash
# Backup Elasticsearch data
sudo tar -czf es-backup-$(date +%Y%m%d).tar.gz es-data/
```

### Cleanup Old Indices

```bash
# Delete indices older than 30 days
for index in $(curl -s -u elastic:$ELASTIC_PASSWORD http://localhost:9200/_cat/indices?h=i | grep -E 'apps-logs|nginx-logs'); do
  date=$(echo $index | grep -oE '[0-9]{4}\.[0-9]{2}\.[0-9]{2}' | tr '.' '-')
  if [[ $(date -d "$date" +%s) -lt $(date -d "30 days ago" +%s) ]]; then
    curl -X DELETE -u elastic:$ELASTIC_PASSWORD http://localhost:9200/$index
  fi
done
```

### Stop the Stack

```bash
sudo docker compose down

# Preserve data
sudo docker compose down --volumes  # WARNING: Deletes all data!
```

## 🔧 Environment Variables

```bash
# Set Elasticsearch password
export ELASTIC_PASSWORD="your-password"

# Pass to compose
sudo -E docker compose up -d
```

## 📚 Additional Resources

- [Elasticsearch Documentation](https://www.elastic.co/guide/en/elasticsearch/reference/current/index.html)
- [Kibana User Guide](https://www.elastic.co/guide/en/kibana/current/index.html)
- [Logstash Configuration](https://www.elastic.co/guide/en/logstash/current/config-examples.html)
- [Filebeat Docker Documentation](https://www.elastic.co/guide/en/beats/filebeat/current/running-on-docker.html)

## 📝 License

MIT License

## 👨‍💻 Support

For issues and questions, please open an issue on GitHub.

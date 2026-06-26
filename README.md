# minimal elk stack

main source - https://habr.com/ru/articles/671344/


gemini suggested fix:
```bash
# Возвращаем права текущему пользователю на всю папку volumes
sudo chown -R $USER:$USER ./docker_volumes

# Накатываем полные права для группы и владельца
chmod -R 775 ./docker_volumes

# Передаем саму папку elasticsearch пользователю 1000 (внутренний эластик)
sudo chown -R 1000:1000 ./docker_volumes/elasticsearch/data
```

usage:
```bash
python3 -m venv venv && source venv/bin/activate && pip install psutil

docker compose up -d

python3 ./host_metrics_app/main.py
```
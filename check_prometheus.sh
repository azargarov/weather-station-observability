docker run --rm \
  --entrypoint /bin/promtool \
  -v "$PWD/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro" \
  -v "$PWD/prometheus/rules:/etc/prometheus/rules:ro" \
  -v "$PWD/prometheus/targets:/etc/prometheus/targets:ro" \
  prom/prometheus \
  check config /etc/prometheus/prometheus.yml


docker run --rm \
  --entrypoint /bin/promtool \
  -v "$PWD/prometheus/rules:/etc/prometheus/rules:ro" \
  prom/prometheus \
  check rules /etc/prometheus/rules/node-alert.yml

# Task 2: Observability - Documentation

## Monitoring vs Observability

| | Monitoring | Observability |
|---|---|---|
| Question it answers | "Is something wrong?" | "**Why** is it wrong?" |
| Works on | Known failure modes (questions you thought of in advance) | Unknown failure modes (questions you think of during an incident) |
| Typical output | Dashboards, thresholds, alerts | The ability to explore metrics, logs and traces together and drill down |
| Example | "CPU of pod X is 95%" alert fires | Find which endpoint, which release and which downstream call made CPU spike |

Monitoring is a **subset** of observability. A system is *observable* when you can understand its
internal state just by looking at the signals it emits - without shipping new code to debug it.

```text
Monitoring    -> tells you THAT something broke   (the smoke alarm)
Observability -> lets you find WHY it broke       (the investigation)
```

---

## The Three Pillars

```text
METRICS -> numbers over time        "HOW MUCH / HOW OFTEN?"
LOGS    -> timestamped events       "WHAT happened?"
TRACES  -> one request's journey    "WHERE did the time go?"
```

### 1. Metrics

**What it is:** A numeric measurement recorded at regular intervals, stored as a time series
`name{labels} value @timestamp`. Cheap to store, fast to query and aggregate, ideal for dashboards and alerts.

```text
container_cpu_usage_seconds_total{namespace="s20-monitoring",pod="s20-cpu-burner-..."}  1234.5
http_request_duration_seconds_count{status="500"}                                       42
up{job="s20-podinfo"}                                                                     1
```

Metric types (Prometheus): **Counter** (only goes up - requests, errors), **Gauge** (goes up and down -
memory, temperature, queue size), **Histogram / Summary** (distribution - latency percentiles).

The golden signals you usually watch: **Latency, Traffic, Errors, Saturation** (CPU / memory).

Used in this homework: CPU and memory of every pod (`kubectl top` + PromQL), request rate and
error rate of podinfo, `up` for application health, all of them feeding the custom alerts.

### 2. Logs

**What it is:** Immutable, timestamped text records of discrete events written by an application
or the system. They carry the **detail and context** a number cannot - error messages, stack traces,
request IDs, user IDs.

```text
2026-10-07T17:01:02Z INFO  app starting...
2026-10-07T17:01:04Z ERROR FATAL: DATABASE_URL is not set
{"level":"debug","ts":"...","msg":"request completed","method":"GET","path":"/status/500","status":500}
```

Best practice: **structured logs** (JSON) so they can be filtered by field, and write to
stdout/stderr so the container runtime collects them (`kubectl logs`).

Used in this homework: `kubectl logs` for the podinfo app (structured JSON request logs),
the load generator and the crash-looping pod (`--previous` shows the log of the container that crashed).

### 3. Traces

**What it is:** A trace follows **one request** as it travels through many services. Each hop is a
**span** (name, start time, duration, parent span). All spans share a **trace ID** that is propagated
in request headers (W3C `traceparent`).

```text
Trace ID: 4bf92f3577b34da6

GET /checkout                      820ms
 ├── api-gateway                    20ms
 ├── order-service                  80ms
 │    └── payment-service          120ms
 └── postgres SELECT ...           600ms   <-- the slow part
```

Traces answer what metrics and logs cannot in a microservice system: *which* service in the chain is
slow or failing for a particular request. They require instrumentation (OpenTelemetry SDK or auto-instrumentation).

### How the pillars work together

```text
1. ALERT fires from a METRIC      -> "error rate of checkout > 5%"
2. Open the TRACE of a failed req -> payment-service span is red, 3s long
3. Jump to the LOGS of that span  -> "connection pool exhausted" (same trace_id in the log line)
```

---

## Why Observability Is Required

- **Distributed systems fail in new ways.** A request can cross 10+ microservices, pods are created and
  destroyed every minute, IPs change - you cannot SSH into "the server" and tail one log file anymore.
- **Faster incident response (lower MTTD / MTTR).** You detect a problem from metrics/alerts before
  users report it, and find the root cause from traces/logs instead of guessing.
- **Unknown unknowns.** Dashboards only show what you predicted. Rich, correlated telemetry lets you
  ask new questions during an outage.
- **Capacity planning and cost.** CPU / memory trends tell you how to size requests/limits, when to
  scale and where money is wasted.
- **SLOs and reliability.** You cannot promise 99.9% availability or p95 latency < 300ms without measuring it.
- **Safe deployments.** Compare error rate and latency before/after a release; roll back automatically (canary analysis).
- **Security and audit.** Logs record who did what and when (Kubernetes audit logs, access logs).

---

## Common Tools

| Pillar / Area | Open source | Managed / commercial |
|---|---|---|
| Metrics collection & storage | **Prometheus**, VictoriaMetrics, Thanos, Mimir | AWS CloudWatch, Google Cloud Monitoring, Datadog |
| Dashboards | **Grafana** | Datadog, New Relic, CloudWatch dashboards |
| Alerting | **Alertmanager**, Grafana Alerting | PagerDuty, Opsgenie |
| Logs | **Loki** + Promtail/Grafana Alloy, ELK/EFK (Elasticsearch, Logstash/**Fluentd**/Fluent Bit, Kibana), OpenSearch | Splunk, CloudWatch Logs, Datadog Logs |
| Traces | **Jaeger**, Grafana **Tempo**, Zipkin | AWS X-Ray, Datadog APM, Honeycomb, Dynatrace |
| Instrumentation standard | **OpenTelemetry** (SDKs + Collector for metrics, logs and traces) | - |
| Kubernetes-specific | kube-state-metrics, node-exporter, metrics-server, cAdvisor (in kubelet) | - |

The stack used in this homework is **kube-prometheus-stack** (Prometheus Operator + Prometheus +
Alertmanager + Grafana + kube-state-metrics + node-exporter), which is the most common way to start
on Kubernetes.

---

## Kubernetes Observability

Kubernetes adds layers that all need to be observed:

```text
Cluster   -> API server, etcd, scheduler, controller-manager health
Node      -> CPU, memory, disk, network of each machine           (node-exporter)
Pod       -> CPU / memory per container, restarts, OOMKills      (cAdvisor in the kubelet)
Object    -> desired vs actual replicas, pod phase, readiness     (kube-state-metrics)
App       -> request rate, errors, latency, business metrics      (app /metrics endpoint)
```

### Built-in signals (no extra install)

| Command | What it shows |
|---|---|
| `kubectl get pods` / `kubectl describe pod` | Status, restarts, probe failures, events |
| `kubectl get events --sort-by=.lastTimestamp` | Scheduling failures, image pulls, OOMKilled, BackOff |
| `kubectl logs <pod> [-c container] [--previous] [-f]` | Container stdout/stderr (the previous crashed container too) |
| `kubectl top nodes` / `kubectl top pods` | Live CPU / memory (needs **metrics-server**) |
| Liveness / readiness / startup probes | The kubelet restarts unhealthy containers and removes non-ready pods from Service endpoints |

### Full observability stack on Kubernetes

```text
                  ┌───────────────────── Kubernetes cluster ─────────────────────┐
                  │                                                              │
  App pods ──/metrics──┐                                                         │
  kubelet/cAdvisor ────┼──scrape──► Prometheus ──rules──► Alertmanager ──► Slack/PagerDuty
  kube-state-metrics ──┤               │                                          │
  node-exporter ───────┘               └──PromQL──► Grafana dashboards            │
                  │                                                              │
  Pod stdout/stderr ──► Fluent Bit / Promtail (DaemonSet) ──► Loki / Elasticsearch
                  │                                                              │
  App (OpenTelemetry SDK) ──OTLP──► OTel Collector ──► Jaeger / Tempo             │
                  └──────────────────────────────────────────────────────────────┘
```

- **Prometheus Operator CRDs** make monitoring declarative: a `ServiceMonitor` says *what* to scrape,
  a `PrometheusRule` says *when to alert* - both are plain YAML that can live in Git (GitOps!).
- Labels (`namespace`, `pod`, `container`, `app`) are attached to every signal, so you can pivot from a
  metric to the logs of the exact same pod.
- Logs on Kubernetes are ephemeral (they disappear with the pod), so a node-level log agent shipping
  them to central storage is essential in production.

See the main [README](../README.md) (Task 1) for the live monitoring demo on minikube that exercises
metrics, logs, alerts and health checks.

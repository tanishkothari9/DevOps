# Session 20: Monitoring, Observability & GitOps

> Work in progress: the full write-up for this session is being finalised. Every screenshot below is real output from commands run on a local minikube cluster / Docker / GitHub Actions.

## Evidence

### g01-install-argocd

```bash
kubectl create namespace argocd && kubectl apply -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml | tail -25
```

![g01-install-argocd](screenshots/g01-install-argocd.png)

### g02-argocd-pods

```bash
kubectl get pods -n argocd -o wide | cut -c1-120 && echo && kubectl get svc -n argocd && echo && kubectl get crd | grep argoproj.io
```

![g02-argocd-pods](screenshots/g02-argocd-pods.png)

### g03-manifests-in-git

```bash
git log --oneline -3 -- gitops/ && git ls-remote origin refs/heads/main && ls gitops/app && echo "--- deployment.yaml as served by GitHub ---" && curl -s https://raw.githubusercontent.com/tanishkothari9/DevOps/main/DevOps-main/Monitoring-Observability-GitOps/gitops/app/deployment.yaml | head -24
```

![g03-manifests-in-git](screenshots/g03-manifests-in-git.png)

### g04-register-app

```bash
cat gitops/argocd-application.yaml && kubectl apply -f gitops/argocd-application.yaml && kubectl get applications -n argocd
```

![g04-register-app](screenshots/g04-register-app.png)

### g05-app-synced

```bash
kubectl get applications -n argocd
```

![g05-app-synced](screenshots/g05-app-synced.png)

### g06-resources-from-git

```bash
kubectl get all -n s20-gitops -o wide
```

![g06-resources-from-git](screenshots/g06-resources-from-git.png)

### g07-change-in-git

```bash
sed -i '' -e 's/replicas: 2/replicas: 3/' -e 's/nginx:1.27-alpine/nginx:1.28-alpine/' gitops/app/deployment.yaml
```

![g07-change-in-git](screenshots/g07-change-in-git.png)

### g08-auto-sync

```bash
git log --oneline -1 origin/main -- gitops/app
```

![g08-auto-sync](screenshots/g08-auto-sync.png)

### g08b-auto-sync-done

```bash
kubectl rollout status deployment/s20-gitops-app -n s20-gitops --timeout=180s
```

![g08b-auto-sync-done](screenshots/g08b-auto-sync-done.png)

### g09-self-heal

```bash
kubectl get applications -n argocd
```

![g09-self-heal](screenshots/g09-self-heal.png)

### g10-rollback-via-git

```bash
sed -i '' -e 's/replicas: 3/replicas: 2/' -e 's/nginx:1.28-alpine/nginx:1.27-alpine/' gitops/app/deployment.yaml
```

![g10-rollback-via-git](screenshots/g10-rollback-via-git.png)

### g11-history

```bash
git log --oneline -4 origin/main -- gitops/app
```

![g11-history](screenshots/g11-history.png)

### m01-cluster

```bash
kubectl config current-context && kubectl get nodes -o wide && minikube addons list | grep -E "metrics-server|ingress |storage-provisioner "
```

![m01-cluster](screenshots/m01-cluster.png)

### m02-helm-repo-add

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts && helm repo update prometheus-community && helm search repo prometheus-community/kube-prometheus-stack
```

![m02-helm-repo-add](screenshots/m02-helm-repo-add.png)

### m03-helm-install-kps

```bash
cd /Users/tanishkothari/Code/learning/sst/devops/DevOps-main/Monitoring-Observability-GitOps && helm upgrade --install kps prometheus-community/kube-prometheus-stack -n monitoring --create-namespace -f monitoring/kps-values.yaml --wait --timeout 10m
```

![m03-helm-install-kps](screenshots/m03-helm-install-kps.png)

### m03b-helm-upgrade-kps

```bash
helm upgrade --install kps prometheus-community/kube-prometheus-stack -n monitoring -f monitoring/kps-values.yaml --wait --timeout 10m && helm list -n monitoring
```

![m03b-helm-upgrade-kps](screenshots/m03b-helm-upgrade-kps.png)

### m03c-helm-upgrade-scrape-timeout

```bash
helm upgrade kps prometheus-community/kube-prometheus-stack -n monitoring -f monitoring/kps-values.yaml --wait --timeout 10m | head -8
```

![m03c-helm-upgrade-scrape-timeout](screenshots/m03c-helm-upgrade-scrape-timeout.png)

### m04-kps-pods

```bash
helm list -n monitoring
```

![m04-kps-pods](screenshots/m04-kps-pods.png)

### m05-apply-demo-app

```bash
cd /Users/tanishkothari/Code/learning/sst/devops/DevOps-main/Monitoring-Observability-GitOps && kubectl apply -f monitoring/demo-app.yaml -f monitoring/servicemonitor.yaml -f monitoring/alert-rules.yaml -f monitoring/grafana-dashboard.yaml
```

![m05-apply-demo-app](screenshots/m05-apply-demo-app.png)

### m06-port-forwards

```bash
ps -eo command | grep "^kubectl --context minikube port-forward"
```

![m06-port-forwards](screenshots/m06-port-forwards.png)

### m07-demo-pods

```bash
kubectl get pods -n s20-monitoring -o wide
```

![m07-demo-pods](screenshots/m07-demo-pods.png)

### m08-app-health-probes

```bash
kubectl describe deploy s20-podinfo -n s20-monitoring | grep -E "Liveness|Readiness|Limits|Requests|cpu|memory"
```

![m08-app-health-probes](screenshots/m08-app-health-probes.png)

### m08b-podinfo-restart

```bash
kubectl rollout restart deployment/s20-podinfo -n s20-monitoring
```

![m08b-podinfo-restart](screenshots/m08b-podinfo-restart.png)

### m09-kubectl-top

```bash
kubectl top nodes
```

![m09-kubectl-top](screenshots/m09-kubectl-top.png)

### m10-promql-cpu-memory

```bash
echo "### CPU (cores) used per pod - rate(container_cpu_usage_seconds_total[2m])"
```

![m10-promql-cpu-memory](screenshots/m10-promql-cpu-memory.png)

### m12-logs

```bash
kubectl logs deploy/s20-podinfo -n s20-monitoring --tail=4
```

![m12-logs](screenshots/m12-logs.png)

### m13-events

```bash
kubectl get events -n s20-monitoring --field-selector reason=BackOff -o custom-columns='LAST:.lastTimestamp,COUNT:.count,OBJECT:.involvedObject.name,MESSAGE:.message' | tail -3
```

![m13-events](screenshots/m13-events.png)

### m14-alert-rules

```bash
kubectl get prometheusrule s20-demo-alerts -n s20-monitoring -o jsonpath='{range .spec.groups[0].rules[*]}{.alert}{"\n"}{end}'
```

![m14-alert-rules](screenshots/m14-alert-rules.png)

### m15-alerts-firing

```bash
curl -s localhost:19090/api/v1/alerts | jq -r '.data.alerts[] | select(.labels.session=="20") | "\(.state | ascii_upcase)\t\(.labels.alertname)\t\(.labels.pod // "-")\tsince \(.activeAt)\t\(.annotations.summary)"'
```

![m15-alerts-firing](screenshots/m15-alerts-firing.png)

### w01-prometheus-targets

![w01-prometheus-targets](screenshots/w01-prometheus-targets.png)

### w05-grafana-1-healthy

![w05-grafana-1-healthy](screenshots/w05-grafana-1-healthy.png)

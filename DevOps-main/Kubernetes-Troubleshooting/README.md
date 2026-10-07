# Session 14: Kubernetes Troubleshooting

> Work in progress: the full write-up for this session is being finalised. Every screenshot below is real output from commands run on a local minikube cluster / Docker / GitHub Actions.

## 01-kubectl-commands

### 01-setup

```bash
kubectl create namespace s14-commands && kubectl apply -n s14-commands -f web-pod.yaml -f logs-pod.yaml -f deployment.yaml && kubectl expose deployment web --port=80 -n s14-commands
```

![01-setup](01-kubectl-commands/screenshots/01-setup.png)

### 02-wait

```bash
kubectl wait --for=condition=Ready pod --all -n s14-commands --timeout=180s
```

![02-wait](01-kubectl-commands/screenshots/02-wait.png)

### 03-get-pods

```bash
kubectl get pods -n s14-commands
```

![03-get-pods](01-kubectl-commands/screenshots/03-get-pods.png)

### 04-get-pods-wide

```bash
kubectl get pods -n s14-commands -o wide
```

![04-get-pods-wide](01-kubectl-commands/screenshots/04-get-pods-wide.png)

### 05-get-all

```bash
kubectl get all -n s14-commands
```

![05-get-all](01-kubectl-commands/screenshots/05-get-all.png)

### 06-get-labels

```bash
kubectl get pods -n s14-commands --show-labels; echo; kubectl get pods -n s14-commands -l app=web
```

![06-get-labels](01-kubectl-commands/screenshots/06-get-labels.png)

### 07-get-yaml

```bash
kubectl get pod get-demo -n s14-commands -o yaml | head -45
```

![07-get-yaml](01-kubectl-commands/screenshots/07-get-yaml.png)

### 08-get-jsonpath

```bash
kubectl get pods -n s14-commands -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,IP:.status.podIP,NODE:.spec.nodeName,IMAGE:.spec.containers[0].image
```

![08-get-jsonpath](01-kubectl-commands/screenshots/08-get-jsonpath.png)

### 09-get-nodes-wide

```bash
kubectl get nodes -o wide; echo; kubectl get svc,endpoints -n s14-commands -o wide
```

![09-get-nodes-wide](01-kubectl-commands/screenshots/09-get-nodes-wide.png)

### 10-describe-pod

```bash
kubectl describe pod get-demo -n s14-commands
```

![10-describe-pod](01-kubectl-commands/screenshots/10-describe-pod.png)

### 11-describe-deployment

```bash
kubectl describe deployment web -n s14-commands
```

![11-describe-deployment](01-kubectl-commands/screenshots/11-describe-deployment.png)

### 12-describe-service

```bash
kubectl describe service web -n s14-commands
```

![12-describe-service](01-kubectl-commands/screenshots/12-describe-service.png)

### 13-describe-node

```bash
kubectl describe node minikube | grep -A12 "Allocated resources"
```

![13-describe-node](01-kubectl-commands/screenshots/13-describe-node.png)

### 14-logs

```bash
kubectl logs logs-demo -n s14-commands
```

![14-logs](01-kubectl-commands/screenshots/14-logs.png)

### 15-logs-tail-timestamps

```bash
kubectl logs logs-demo -n s14-commands --tail=3 --timestamps
```

![15-logs-tail-timestamps](01-kubectl-commands/screenshots/15-logs-tail-timestamps.png)

### 16-logs-follow

```bash
kubectl logs -f logs-demo -n s14-commands --since=5s & PID=$!; sleep 12; kill $PID; echo "(stopped following after 12s)"
```

![16-logs-follow](01-kubectl-commands/screenshots/16-logs-follow.png)

### 17-logs-deployment-label

```bash
kubectl exec get-demo -n s14-commands -- curl -s -o /dev/null http://web; kubectl logs deployment/web -n s14-commands --tail=3; echo; kubectl logs -l app=web -n s14-commands --tail=2 --prefix
```

![17-logs-deployment-label](01-kubectl-commands/screenshots/17-logs-deployment-label.png)

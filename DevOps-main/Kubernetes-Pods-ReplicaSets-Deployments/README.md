# Session 10: Kubernetes Pods, ReplicaSets & Deployments

> Work in progress: the full write-up for this session is being finalised. Every screenshot below is real output from commands run on a local minikube cluster / Docker / GitHub Actions.

## Evidence

### 01-create-namespaces

```bash
for ns in s10-core s10-rolling s10-bluegreen s10-canary s10-recreate s10-lifecycle s10-troubleshoot; do kubectl create namespace $ns; done
```

![01-create-namespaces](screenshots/01-create-namespaces.png)

### 02-pod-apply

```bash
kubectl apply -f 00-core-objects/pod.yaml -n s10-core && kubectl wait --for=condition=Ready pod/yatri-demo-pod -n s10-core --timeout=180s && kubectl get pod yatri-demo-pod -n s10-core -o wide --show-labels
```

![02-pod-apply](screenshots/02-pod-apply.png)

### 03-pod-describe

```bash
kubectl describe pod yatri-demo-pod -n s10-core | sed -n "1,11p;/^Containers:/,/Mounts:/p;/^Conditions:/,/^Volumes:/p"
```

![03-pod-describe](screenshots/03-pod-describe.png)

### 04-pod-logs-exec

```bash
kubectl logs yatri-demo-pod -n s10-core --tail=3; kubectl exec yatri-demo-pod -n s10-core -- sh -c "hostname; nginx -v; wget -qO- localhost | grep title"
```

![04-pod-logs-exec](screenshots/04-pod-logs-exec.png)

### 05-pod-delete-no-healing

```bash
kubectl delete pod yatri-demo-pod -n s10-core && kubectl get pods -n s10-core
```

![05-pod-delete-no-healing](screenshots/05-pod-delete-no-healing.png)

### 06-replicaset-apply

```bash
kubectl apply -f 00-core-objects/replicaset.yaml -n s10-core && sleep 3 && kubectl wait --for=condition=Ready pod -l app=yatri-backend -n s10-core --timeout=180s >/dev/null && kubectl get rs,pods -n s10-core -o wide
```

![06-replicaset-apply](screenshots/06-replicaset-apply.png)

### 07-replicaset-self-healing

```bash
POD=$(kubectl get pods -l app=yatri-backend -n s10-core -o jsonpath="{.items[0].metadata.name}"); echo "deleting $POD ..."; kubectl delete pod $POD -n s10-core --wait=false; sleep 2; kubectl get pods -l app=yatri-backend -n s10-core; echo; kubectl describe rs yatri-backend-rs -n s10-core | sed -n "/^Events:/,\$p"
```

![07-replicaset-self-healing](screenshots/07-replicaset-self-healing.png)

### 08-replicaset-scale

```bash
kubectl scale rs yatri-backend-rs --replicas=5 -n s10-core && sleep 4 && kubectl get rs yatri-backend-rs -n s10-core && kubectl scale rs yatri-backend-rs --replicas=2 -n s10-core && sleep 4 && kubectl get pods -l app=yatri-backend -n s10-core
```

![08-replicaset-scale](screenshots/08-replicaset-scale.png)

### 09-replicaset-owner

```bash
kubectl get pods -l app=yatri-backend -n s10-core -o custom-columns=POD:.metadata.name,OWNER-KIND:.metadata.ownerReferences[0].kind,OWNER:.metadata.ownerReferences[0].name
```

![09-replicaset-owner](screenshots/09-replicaset-owner.png)

### 10-statefulset-apply

```bash
kubectl apply -f 00-core-objects/statefulset.yaml -n s10-core && kubectl rollout status statefulset/web -n s10-core --timeout=300s && kubectl get statefulset,pods,pvc -l app=web-sts -n s10-core -o wide; kubectl get pvc -n s10-core
```

![10-statefulset-apply](screenshots/10-statefulset-apply.png)

### 11-statefulset-ordered-creation

```bash
kubectl get pods -l app=web-sts -n s10-core -o custom-columns=POD:.metadata.name,CREATED:.metadata.creationTimestamp,IP:.status.podIP; echo; kubectl get events -n s10-core --sort-by=.lastTimestamp | grep "statefulset/web"
```

![11-statefulset-ordered-creation](screenshots/11-statefulset-ordered-creation.png)

### 12-statefulset-stable-identity

```bash
echo "BEFORE:"; kubectl get pod web-1 -n s10-core -o wide | tail -1; kubectl delete pod web-1 -n s10-core; kubectl wait --for=condition=Ready pod/web-1 -n s10-core --timeout=120s >/dev/null; echo "AFTER (same name, same PVC, new IP):"; kubectl get pod web-1 -n s10-core -o wide | tail -1; kubectl get pod web-1 -n s10-core -o jsonpath="volume claim: {.spec.volumes[0].persistentVolumeClaim.claimName} ...
```

![12-statefulset-stable-identity](screenshots/12-statefulset-stable-identity.png)

### 13-statefulset-dns

```bash
kubectl exec web-0 -n s10-core -- nslookup web-2.web-sts.s10-core.svc.cluster.local
```

![13-statefulset-dns](screenshots/13-statefulset-dns.png)

### 14-daemonset-apply

```bash
kubectl apply -f 00-core-objects/daemonset.yaml -n s10-core && kubectl rollout status daemonset/node-logging-agent -n s10-core --timeout=120s && kubectl get daemonset node-logging-agent -n s10-core -o wide && kubectl get pods -l app=node-logging-agent -n s10-core -o wide && kubectl get nodes
```

![14-daemonset-apply](screenshots/14-daemonset-apply.png)

### 15-daemonset-logs

```bash
sleep 12; kubectl logs -l app=node-logging-agent -n s10-core --tail=3; echo; kubectl get daemonsets -A
```

![15-daemonset-logs](screenshots/15-daemonset-logs.png)

### 16-cleanup-core

```bash
kubectl delete -f 00-core-objects/ -n s10-core && kubectl delete pvc -l app=web-sts -n s10-core; kubectl delete pvc data-web-0 data-web-1 data-web-2 -n s10-core --ignore-not-found; kubectl get all,pvc -n s10-core
```

![16-cleanup-core](screenshots/16-cleanup-core.png)

### 17-rolling-apply-v1

```bash
kubectl apply -f 01-rolling-update/deployment-v1.yaml -f 01-rolling-update/service.yaml -f curl-client.yaml -n s10-rolling && kubectl rollout status deployment/app-rolling -n s10-rolling --timeout=180s && kubectl wait --for=condition=Ready pod/curl-client -n s10-rolling --timeout=120s >/dev/null && kubectl get deploy,rs,svc -n s10-rolling && kubectl get pods -n s10-rolling -l app=app-rolling -L ve ...
```

![17-rolling-apply-v1](screenshots/17-rolling-apply-v1.png)

### 18-rolling-curl-v1

```bash
kubectl exec curl-client -n s10-rolling -- sh -c "for i in 1 2 3 4 5 6; do curl -s http://app-rolling-service; done"
```

![18-rolling-curl-v1](screenshots/18-rolling-curl-v1.png)

### 19-rolling-update-to-v2

```bash
(kubectl get pods -n s10-rolling -l app=app-rolling -L version -w --output-watch-events --request-timeout=120s | while IFS= read -r l; do echo "$(date +%T) $l"; done) > $W/roll-watch.txt 2>&1 &
```

![19-rolling-update-to-v2](screenshots/19-rolling-update-to-v2.png)

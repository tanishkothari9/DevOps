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

### 19b-rolling-traffic-during-update

```bash
echo "70 requests (1 every 0.5s) sent from curl-client while the rollout ran - consecutive runs:"; cut -d"|" -f1 $W/roll-curl.txt | uniq -c; echo "FAILED requests: $(grep -c FAILED $W/roll-curl.txt) of $(wc -l < $W/roll-curl.txt)"
```

![19b-rolling-traffic-during-update](screenshots/19b-rolling-traffic-during-update.png)

### 20-rolling-after-update

```bash
kubectl get rs -n s10-rolling -L version; kubectl get pods -n s10-rolling -l app=app-rolling -L version; kubectl get events -n s10-rolling --sort-by=.lastTimestamp | grep ScalingReplicaSet
```

![20-rolling-after-update](screenshots/20-rolling-after-update.png)

### 21-rolling-curl-v2

```bash
kubectl exec curl-client -n s10-rolling -- sh -c "for i in 1 2 3 4; do curl -s http://app-rolling-service; done"; kubectl rollout history deployment/app-rolling -n s10-rolling
```

![21-rolling-curl-v2](screenshots/21-rolling-curl-v2.png)

### 22-rolling-rollout-undo

```bash
kubectl rollout undo deployment/app-rolling -n s10-rolling && kubectl rollout status deployment/app-rolling -n s10-rolling --timeout=180s && kubectl get rs -n s10-rolling -L version && kubectl get pods -n s10-rolling -l app=app-rolling -L version && kubectl exec curl-client -n s10-rolling -- sh -c "for i in 1 2 3; do curl -s http://app-rolling-service; done" && kubectl rollout history deployment/a ...
```

![22-rolling-rollout-undo](screenshots/22-rolling-rollout-undo.png)

### 22b-rolling-undo-complete

```bash
kubectl rollout status deployment/app-rolling -n s10-rolling; kubectl get rs -n s10-rolling -L version; kubectl get pods -n s10-rolling -l app=app-rolling -L version; kubectl exec curl-client -n s10-rolling -- sh -c "for i in 1 2 3 4; do curl -s -m 3 http://app-rolling-service; done"; kubectl rollout history deployment/app-rolling -n s10-rolling
```

![22b-rolling-undo-complete](screenshots/22b-rolling-undo-complete.png)

### 23-rolling-cleanup

```bash
kubectl delete namespace s10-rolling --wait=false
```

![23-rolling-cleanup](screenshots/23-rolling-cleanup.png)

### 24-bluegreen-deploy-blue

```bash
kubectl apply -f 02-blue-green/deployment-blue.yaml -f 02-blue-green/service-blue.yaml -f curl-client.yaml -n s10-bluegreen && kubectl rollout status deployment/app-blue -n s10-bluegreen --timeout=900s && kubectl wait --for=condition=Ready pod/curl-client -n s10-bluegreen --timeout=600s >/dev/null && kubectl get deploy,svc -n s10-bluegreen && kubectl get pods -n s10-bluegreen -L slot,version
```

![24-bluegreen-deploy-blue](screenshots/24-bluegreen-deploy-blue.png)

### 25-bluegreen-traffic-blue

```bash
kubectl get svc myapp-service -n s10-bluegreen -o jsonpath='selector: {.spec.selector}{"\n"}'; kubectl get endpointslices -l kubernetes.io/service-name=myapp-service -n s10-bluegreen; kubectl exec curl-client -n s10-bluegreen -- sh -c "for i in 1 2 3 4 5 6; do curl -s -m 5 http://myapp-service; done"
```

![25-bluegreen-traffic-blue](screenshots/25-bluegreen-traffic-blue.png)

### 26-bluegreen-deploy-green

```bash
kubectl apply -f 02-blue-green/deployment-green.yaml -n s10-bluegreen && kubectl rollout status deployment/app-green -n s10-bluegreen --timeout=900s && kubectl get pods -n s10-bluegreen -L slot,version -o wide; echo '--- green is running but receives NO traffic yet:'; kubectl exec curl-client -n s10-bluegreen -- sh -c "for i in 1 2 3 4 5 6; do curl -s -m 5 http://myapp-service; done"
```

![26-bluegreen-deploy-green](screenshots/26-bluegreen-deploy-green.png)

### 27-bluegreen-test-green-directly

```bash
GREEN_IP=$(kubectl get pods -l slot=green -n s10-bluegreen -o jsonpath='{.items[0].status.podIP}'); echo "smoke-testing green pod directly at $GREEN_IP"; kubectl exec curl-client -n s10-bluegreen -- curl -s -m 5 http://$GREEN_IP
```

![27-bluegreen-test-green-directly](screenshots/27-bluegreen-test-green-directly.png)

### 28-bluegreen-switch-to-green

```bash
date +%T; kubectl apply -f 02-blue-green/service-green.yaml -n s10-bluegreen && kubectl get svc myapp-service -n s10-bluegreen -o jsonpath='selector: {.spec.selector}{"\n"}'; sleep 3; kubectl get endpointslices -l kubernetes.io/service-name=myapp-service -n s10-bluegreen; kubectl exec curl-client -n s10-bluegreen -- sh -c "for i in 1 2 3 4 5 6; do curl -s -m 5 http://myapp-service; done"
```

![28-bluegreen-switch-to-green](screenshots/28-bluegreen-switch-to-green.png)

### 29-bluegreen-rollback-to-blue

```bash
kubectl apply -f 02-blue-green/service-blue.yaml -n s10-bluegreen && kubectl get svc myapp-service -n s10-bluegreen -o jsonpath='selector: {.spec.selector}{"\n"}'; sleep 3; kubectl exec curl-client -n s10-bluegreen -- sh -c "for i in 1 2 3 4 5 6; do curl -s -m 5 http://myapp-service; done"
```

![29-bluegreen-rollback-to-blue](screenshots/29-bluegreen-rollback-to-blue.png)

### 30-bluegreen-final-green-retire-blue

```bash
kubectl apply -f 02-blue-green/service-green.yaml -n s10-bluegreen && sleep 3 && kubectl exec curl-client -n s10-bluegreen -- sh -c "for i in 1 2 3 4 5 6; do curl -s -m 5 http://myapp-service; done" && kubectl scale deployment app-blue --replicas=0 -n s10-bluegreen && kubectl get deploy -n s10-bluegreen
```

![30-bluegreen-final-green-retire-blue](screenshots/30-bluegreen-final-green-retire-blue.png)

### 31-bluegreen-cleanup

```bash
kubectl delete namespace s10-bluegreen --wait=false
```

![31-bluegreen-cleanup](screenshots/31-bluegreen-cleanup.png)

### 39-recreate-deploy-v1

```bash
kubectl apply -f 04-recreate/deployment-v1.yaml -f 04-recreate/service.yaml -f curl-client.yaml -n s10-recreate && kubectl rollout status deployment/app-recreate -n s10-recreate --timeout=900s && kubectl wait --for=condition=Ready pod/curl-client -n s10-recreate --timeout=600s >/dev/null && kubectl get deploy,rs,svc -n s10-recreate && kubectl get pods -n s10-recreate -l app=app-recreate -L version ...
```

![39-recreate-deploy-v1](screenshots/39-recreate-deploy-v1.png)

### 40-lifecycle-apply-01-running

```bash
kubectl apply -f pod-lifecycle/01-running.yaml -n s10-lifecycle && date +%T && kubectl get pods -n s10-lifecycle
```

![40-lifecycle-apply-01-running](screenshots/40-lifecycle-apply-01-running.png)

### 40-recreate-update-to-v2

```bash
(kubectl get pods -n s10-recreate -l app=app-recreate -L version -w --output-watch-events --request-timeout=600s | while IFS= read -r l; do echo "$(date +%T) $l"; done) > $W/rec-watch.txt 2>&1 &
```

![40-recreate-update-to-v2](screenshots/40-recreate-update-to-v2.png)

### 41-lifecycle-apply-02-pending

```bash
kubectl apply -f pod-lifecycle/02-pending.yaml -n s10-lifecycle && date +%T && kubectl get pods -n s10-lifecycle
```

![41-lifecycle-apply-02-pending](screenshots/41-lifecycle-apply-02-pending.png)

### 41-recreate-pod-watch

```bash
cat $W/rec-watch.txt
```

![41-recreate-pod-watch](screenshots/41-recreate-pod-watch.png)

### 42-lifecycle-apply-03-succeeded

```bash
kubectl apply -f pod-lifecycle/03-succeeded.yaml -n s10-lifecycle && date +%T && kubectl get pods -n s10-lifecycle
```

![42-lifecycle-apply-03-succeeded](screenshots/42-lifecycle-apply-03-succeeded.png)

### 42-recreate-traffic-during-update

```bash
echo "requests (every 0.5s) while Recreate ran - consecutive runs:"; cut -c10- $W/rec-curl.txt | cut -d"|" -f1-2 | uniq -c; echo; echo "first and last failure:"; grep FAILED $W/rec-curl.txt | sed -n "1p;\$p"
```

![42-recreate-traffic-during-update](screenshots/42-recreate-traffic-during-update.png)

### 43-lifecycle-apply-04-failed

```bash
kubectl apply -f pod-lifecycle/04-failed.yaml -n s10-lifecycle && date +%T && kubectl get pods -n s10-lifecycle
```

![43-lifecycle-apply-04-failed](screenshots/43-lifecycle-apply-04-failed.png)

### 43-recreate-events

```bash
kubectl get events -n s10-recreate --sort-by=.lastTimestamp | grep -E 'ScalingReplicaSet|Killing|Started' | grep -v curl-client; kubectl get rs -n s10-recreate -L version
```

![43-recreate-events](screenshots/43-recreate-events.png)

### 44-lifecycle-apply-05-crashloopbackoff

```bash
kubectl apply -f pod-lifecycle/05-crashloopbackoff.yaml -n s10-lifecycle && date +%T && kubectl get pods -n s10-lifecycle
```

![44-lifecycle-apply-05-crashloopbackoff](screenshots/44-lifecycle-apply-05-crashloopbackoff.png)

### 44-recreate-cleanup

```bash
kubectl delete namespace s10-recreate --wait=false
```

![44-recreate-cleanup](screenshots/44-recreate-cleanup.png)

### 45-lifecycle-apply-06-imagepullbackoff

```bash
kubectl apply -f pod-lifecycle/06-imagepullbackoff.yaml -n s10-lifecycle && date +%T && kubectl get pods -n s10-lifecycle
```

![45-lifecycle-apply-06-imagepullbackoff](screenshots/45-lifecycle-apply-06-imagepullbackoff.png)

### 46-lifecycle-apply-07-readiness

```bash
kubectl apply -f pod-lifecycle/07-readiness.yaml -n s10-lifecycle && date +%T && kubectl get pods -n s10-lifecycle
```

![46-lifecycle-apply-07-readiness](screenshots/46-lifecycle-apply-07-readiness.png)

### 47-lifecycle-apply-08-liveness

```bash
kubectl apply -f pod-lifecycle/08-liveness.yaml -n s10-lifecycle && date +%T && kubectl get pods -n s10-lifecycle
```

![47-lifecycle-apply-08-liveness](screenshots/47-lifecycle-apply-08-liveness.png)

### 48-lifecycle-apply-09-startup

```bash
kubectl apply -f pod-lifecycle/09-startup.yaml -n s10-lifecycle && date +%T && kubectl get pods -n s10-lifecycle
```

![48-lifecycle-apply-09-startup](screenshots/48-lifecycle-apply-09-startup.png)

### 49-lifecycle-apply-10-init-container

```bash
kubectl apply -f pod-lifecycle/10-init-container.yaml -n s10-lifecycle && date +%T && kubectl get pods -n s10-lifecycle
```

![49-lifecycle-apply-10-init-container](screenshots/49-lifecycle-apply-10-init-container.png)

### 50-lifecycle-apply-11-multi-container

```bash
kubectl apply -f pod-lifecycle/11-multi-container.yaml -n s10-lifecycle && date +%T && kubectl get pods -n s10-lifecycle
```

![50-lifecycle-apply-11-multi-container](screenshots/50-lifecycle-apply-11-multi-container.png)

### 51-lifecycle-get-all

```bash
date +%T; kubectl get pods -n s10-lifecycle -o wide
```

![51-lifecycle-get-all](screenshots/51-lifecycle-get-all.png)

### 52-lc-01-running

```bash
kubectl get pod lifecycle-running -n s10-lifecycle -o wide; kubectl describe pod lifecycle-running -n s10-lifecycle | sed -n "/^Status:/p;/^    State:/,/Restart Count:/p;/^Conditions:/,/^Volumes:/p;/^Events:/,\$p"; kubectl get pod lifecycle-running -n s10-lifecycle -o jsonpath='{.status.phase} {.status.containerStatuses[0].state}{"\n"}'
```

![52-lc-01-running](screenshots/52-lc-01-running.png)

### 53-lc-02-pending

```bash
kubectl get pod lifecycle-pending -n s10-lifecycle -o wide; kubectl describe pod lifecycle-pending -n s10-lifecycle | sed -n '/^Status:/p;/Requests:/,/memory/p;/^Conditions:/,$p'
```

![53-lc-02-pending](screenshots/53-lc-02-pending.png)

### 54-lc-03-succeeded

```bash
kubectl get pod lifecycle-succeeded -n s10-lifecycle; kubectl describe pod lifecycle-succeeded -n s10-lifecycle | sed -n "/^Status:/p;/^    State:/,/Restart Count:/p;/^Conditions:/,/^Volumes:/p;/^Events:/,\$p"; kubectl logs lifecycle-succeeded -n s10-lifecycle
```

![54-lc-03-succeeded](screenshots/54-lc-03-succeeded.png)

### 55-lc-04-failed

```bash
kubectl get pod lifecycle-failed -n s10-lifecycle; kubectl describe pod lifecycle-failed -n s10-lifecycle | sed -n "/^Status:/p;/^    State:/,/Restart Count:/p;/^Conditions:/,/^Volumes:/p;/^Events:/,\$p"; kubectl logs lifecycle-failed -n s10-lifecycle
```

![55-lc-04-failed](screenshots/55-lc-04-failed.png)

### 56-lc-05-crashloopbackoff

```bash
kubectl get pod lifecycle-crashloop -n s10-lifecycle; kubectl describe pod lifecycle-crashloop -n s10-lifecycle | sed -n '/^    State:/,/Restart Count:/p;/^Events:/,$p'; echo '--- logs (current):'; kubectl logs lifecycle-crashloop -n s10-lifecycle; echo '--- logs --previous:'; kubectl logs lifecycle-crashloop -n s10-lifecycle --previous
```

![56-lc-05-crashloopbackoff](screenshots/56-lc-05-crashloopbackoff.png)

### 56b-lc-05-crashloopbackoff-later

```bash
kubectl get pod lifecycle-crashloop -n s10-lifecycle; kubectl describe pod lifecycle-crashloop -n s10-lifecycle | sed -n '/^    State:/,/Restart Count:/p;/^Events:/,$p'; echo '--- logs --previous:'; kubectl logs lifecycle-crashloop -n s10-lifecycle --previous
```

![56b-lc-05-crashloopbackoff-later](screenshots/56b-lc-05-crashloopbackoff-later.png)

### 57-lc-06-imagepullbackoff

```bash
kubectl get pod lifecycle-image-error -n s10-lifecycle; kubectl describe pod lifecycle-image-error -n s10-lifecycle | sed -n '/^    Image:/p;/^    State:/,/Ready:/p;/^Events:/,$p'
```

![57-lc-06-imagepullbackoff](screenshots/57-lc-06-imagepullbackoff.png)

### 57b-lc-06-imagepullbackoff-later

```bash
kubectl get pod lifecycle-image-error -n s10-lifecycle; kubectl describe pod lifecycle-image-error -n s10-lifecycle | sed -n '/^    Image:/p;/^    State:/,/Ready:/p;/^Events:/,$p'
```

![57b-lc-06-imagepullbackoff-later](screenshots/57b-lc-06-imagepullbackoff-later.png)

### 58-lc-07-readiness

```bash
kubectl get pod lifecycle-readiness -n s10-lifecycle; kubectl describe pod lifecycle-readiness -n s10-lifecycle | sed -n '/^    Readiness:/p;/^    State:/,/Restart Count:/p;/^Conditions:/,/^Volumes:/p;/^Events:/,$p'
```

![58-lc-07-readiness](screenshots/58-lc-07-readiness.png)

### 59-lc-08-liveness

```bash
kubectl get pod lifecycle-liveness -n s10-lifecycle; kubectl describe pod lifecycle-liveness -n s10-lifecycle | sed -n '/^    Liveness:/p;/^    State:/,/Restart Count:/p;/^Events:/,$p'; kubectl logs lifecycle-liveness -n s10-lifecycle
```

![59-lc-08-liveness](screenshots/59-lc-08-liveness.png)

### 59b-lc-08-liveness-later

```bash
kubectl get pod lifecycle-liveness -n s10-lifecycle; kubectl describe pod lifecycle-liveness -n s10-lifecycle | sed -n '/^    Liveness:/p;/^    State:/,/Restart Count:/p;/^Events:/,$p'; echo '--- logs --previous:'; kubectl logs lifecycle-liveness -n s10-lifecycle --previous
```

![59b-lc-08-liveness-later](screenshots/59b-lc-08-liveness-later.png)

### 60-lc-09-startup

```bash
kubectl get pod lifecycle-startup -n s10-lifecycle; kubectl describe pod lifecycle-startup -n s10-lifecycle | sed -n '/^    Startup:/p;/^    State:/,/Restart Count:/p;/^Events:/,$p'; kubectl logs lifecycle-startup -n s10-lifecycle
```

![60-lc-09-startup](screenshots/60-lc-09-startup.png)

### 60b-lc-09-startup-later

```bash
kubectl get pod lifecycle-startup -n s10-lifecycle; kubectl describe pod lifecycle-startup -n s10-lifecycle | sed -n '/^    Startup:/p;/^    State:/,/Restart Count:/p;/^Events:/,$p'
```

![60b-lc-09-startup-later](screenshots/60b-lc-09-startup-later.png)

### 61-lc-10-init-container

```bash
kubectl get pod lifecycle-init -n s10-lifecycle; kubectl describe pod lifecycle-init -n s10-lifecycle | sed -n '/^Init Containers:/,/Restart Count:/p;/^Events:/,$p'; echo '--- init container logs:'; kubectl logs lifecycle-init -c setup -n s10-lifecycle
```

![61-lc-10-init-container](screenshots/61-lc-10-init-container.png)

### 62-lc-11-multi-container

```bash
kubectl get pod lifecycle-multi-container -n s10-lifecycle; kubectl get pod lifecycle-multi-container -n s10-lifecycle -o jsonpath='{range .status.containerStatuses[*]}{.name}{" ready="}{.ready}{" "}{.state}{"\n"}{end}'; echo '--- logs -c sidecar:'; kubectl logs lifecycle-multi-container -c sidecar -n s10-lifecycle --tail=3; echo '--- logs -c app:'; kubectl logs lifecycle-multi-container -c app -n ...
```

![62-lc-11-multi-container](screenshots/62-lc-11-multi-container.png)

### 63-lc-12-termination-apply

```bash
kubectl get pod lifecycle-termination -n s10-lifecycle; kubectl get pod lifecycle-termination -n s10-lifecycle -o jsonpath='terminationGracePeriodSeconds={.spec.terminationGracePeriodSeconds}{"\n"}'; kubectl logs lifecycle-termination -n s10-lifecycle
```

![63-lc-12-termination-apply](screenshots/63-lc-12-termination-apply.png)

### 64-lc-get-all-later

```bash
date +%T; kubectl get pods -n s10-lifecycle
```

![64-lc-get-all-later](screenshots/64-lc-get-all-later.png)

### 65-lc-12-termination-delete

```bash
kubectl logs -f lifecycle-termination -n s10-lifecycle > $W/term-logs.txt 2>&1 & echo "delete started : $(date +%T)"; kubectl delete pod lifecycle-termination -n s10-lifecycle; echo "delete finished: $(date +%T)"; sleep 1; echo '--- container logs captured while it was shutting down:'; cat $W/term-logs.txt
```

![65-lc-12-termination-delete](screenshots/65-lc-12-termination-delete.png)

### 66-lc-cleanup-others

```bash
kubectl delete pod lifecycle-running lifecycle-pending lifecycle-succeeded lifecycle-failed lifecycle-crashloop lifecycle-image-error lifecycle-readiness lifecycle-liveness lifecycle-startup lifecycle-init lifecycle-multi-container -n s10-lifecycle --wait=false
```

![66-lc-cleanup-others](screenshots/66-lc-cleanup-others.png)

### 67-lc-12-termination-reapply

```bash
kubectl apply -f pod-lifecycle/12-termination.yaml -n s10-lifecycle && kubectl wait --for=condition=Ready pod/lifecycle-termination -n s10-lifecycle --timeout=900s && kubectl get pod lifecycle-termination -n s10-lifecycle && kubectl logs lifecycle-termination -n s10-lifecycle
```

![67-lc-12-termination-reapply](screenshots/67-lc-12-termination-reapply.png)

### 68-lc-12-termination-delete

```bash
kubectl logs -f lifecycle-termination -n s10-lifecycle > $W/term-logs.txt 2>&1 & echo "delete started : $(date +%T)"; kubectl delete pod lifecycle-termination -n s10-lifecycle; echo "delete finished: $(date +%T)"; sleep 1; echo '--- container logs captured (kubectl logs -f) while it was shutting down:'; cat $W/term-logs.txt
```

![68-lc-12-termination-delete](screenshots/68-lc-12-termination-delete.png)

### 70-drill-image-baseline

```bash
kubectl apply -f troubleshooting/backend-good.yaml -n s10-troubleshoot && kubectl rollout status deployment/yatri-backend -n s10-troubleshoot --timeout=900s && kubectl get pods -n s10-troubleshoot -L version
```

![70-drill-image-baseline](screenshots/70-drill-image-baseline.png)

### 71-drill-image-apply-broken

```bash
kubectl apply -f troubleshooting/broken-image.yaml -n s10-troubleshoot; kubectl rollout status deployment/yatri-backend -n s10-troubleshoot --timeout=90s; kubectl get deploy,rs -n s10-troubleshoot; kubectl get pods -n s10-troubleshoot -L version
```

![71-drill-image-apply-broken](screenshots/71-drill-image-apply-broken.png)

### 72-drill-image-diagnose

```bash
POD=$(kubectl get pods -n s10-troubleshoot -l version=broken-v3 -o jsonpath='{.items[0].metadata.name}'); kubectl describe pod $POD -n s10-troubleshoot | sed -n '/^    Image:/p;/^    State:/,/Reason:/p;/^Events:/,$p'
```

![72-drill-image-diagnose](screenshots/72-drill-image-diagnose.png)

### 73-drill-image-rollback

```bash
kubectl rollout undo deployment/yatri-backend -n s10-troubleshoot && kubectl rollout status deployment/yatri-backend -n s10-troubleshoot --timeout=600s && kubectl get pods -n s10-troubleshoot -L version && kubectl rollout history deployment/yatri-backend -n s10-troubleshoot
```

![73-drill-image-rollback](screenshots/73-drill-image-rollback.png)

### 74-drill-selector-mismatch

```bash
kubectl apply -f troubleshooting/selector-mismatch.yaml -n s10-troubleshoot
```

![74-drill-selector-mismatch](screenshots/74-drill-selector-mismatch.png)

### 75-drill-selector-fixed

```bash
diff troubleshooting/selector-mismatch.yaml troubleshooting/selector-fixed.yaml; kubectl apply -f troubleshooting/selector-fixed.yaml -n s10-troubleshoot && kubectl rollout status deployment/selector-error-demo -n s10-troubleshoot --timeout=600s && kubectl get deploy selector-error-demo -n s10-troubleshoot -o wide
```

![75-drill-selector-fixed](screenshots/75-drill-selector-fixed.png)

### 76-drill-cleanup

```bash
kubectl delete namespace s10-troubleshoot s10-core               --wait=false
```

![76-drill-cleanup](screenshots/76-drill-cleanup.png)

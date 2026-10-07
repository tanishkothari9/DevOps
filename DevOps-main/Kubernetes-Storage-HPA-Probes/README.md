# Session 13: Kubernetes Storage, HPA & Probes

> Work in progress: the full write-up for this session is being finalised. Every screenshot below is real output from commands run on a local minikube cluster / Docker / GitHub Actions.

## 01-kubernetes-volumes

### 01-apply-emptydir

```bash
kubectl apply -f 00-namespace.yaml -f 01-emptydir-pod.yaml
```

![01-apply-emptydir](01-kubernetes-volumes/screenshots/01-apply-emptydir.png)

### 02-wait-emptydir

```bash
kubectl wait --for=condition=Ready pod/emptydir-demo -n s13-volumes --timeout=180s && kubectl get pod emptydir-demo -n s13-volumes -o wide
```

![02-wait-emptydir](01-kubernetes-volumes/screenshots/02-wait-emptydir.png)

### 03-emptydir-read-from-web

```bash
kubectl exec emptydir-demo -n s13-volumes -c web -- cat /usr/share/nginx/html/index.html
```

![03-emptydir-read-from-web](01-kubernetes-volumes/screenshots/03-emptydir-read-from-web.png)

### 04-emptydir-curl

```bash
kubectl exec emptydir-demo -n s13-volumes -c web -- curl -s localhost
```

![04-emptydir-curl](01-kubernetes-volumes/screenshots/04-emptydir-curl.png)

### 05-emptydir-both-mounts

```bash
kubectl exec emptydir-demo -n s13-volumes -c writer -- ls -l /shared; kubectl exec emptydir-demo -n s13-volumes -c web -- ls -l /usr/share/nginx/html; kubectl describe pod emptydir-demo -n s13-volumes | grep -A4 "^Volumes:"
```

![05-emptydir-both-mounts](01-kubernetes-volumes/screenshots/05-emptydir-both-mounts.png)

### 06-emptydir-delete-recreate

```bash
kubectl delete pod emptydir-demo -n s13-volumes && kubectl apply -f 01-emptydir-pod.yaml && kubectl wait --for=condition=Ready pod/emptydir-demo -n s13-volumes --timeout=120s && sleep 3 && kubectl exec emptydir-demo -n s13-volumes -c web -- cat /usr/share/nginx/html/index.html
```

![06-emptydir-delete-recreate](01-kubernetes-volumes/screenshots/06-emptydir-delete-recreate.png)

### 07-apply-hostpath

```bash
kubectl apply -f 02-hostpath-pod.yaml && kubectl wait --for=condition=Ready pod/hostpath-demo -n s13-volumes --timeout=120s && kubectl get pod hostpath-demo -n s13-volumes -o wide
```

![07-apply-hostpath](01-kubernetes-volumes/screenshots/07-apply-hostpath.png)

### 08-hostpath-write

```bash
kubectl exec hostpath-demo -n s13-volumes -- sh -c "echo hello-from-hostpath-pod > /data/hello.txt && cat /data/hello.txt"
```

![08-hostpath-write](01-kubernetes-volumes/screenshots/08-hostpath-write.png)

### 09-hostpath-on-node

```bash
minikube ssh "ls -l /tmp/s13-hostpath-data && cat /tmp/s13-hostpath-data/hello.txt"
```

![09-hostpath-on-node](01-kubernetes-volumes/screenshots/09-hostpath-on-node.png)

### 10-hostpath-delete-recreate

```bash
kubectl delete pod hostpath-demo -n s13-volumes && kubectl apply -f 02-hostpath-pod.yaml && kubectl wait --for=condition=Ready pod/hostpath-demo -n s13-volumes --timeout=120s && kubectl exec hostpath-demo -n s13-volumes -- cat /data/hello.txt
```

![10-hostpath-delete-recreate](01-kubernetes-volumes/screenshots/10-hostpath-delete-recreate.png)

### 11-apply-pv

```bash
kubectl apply -f 03-pv.yaml && kubectl get pv s13-static-pv
```

![11-apply-pv](01-kubernetes-volumes/screenshots/11-apply-pv.png)

### 12-apply-pvc-bound

```bash
kubectl apply -f 04-pvc.yaml && sleep 3 && kubectl get pv s13-static-pv && kubectl get pvc static-pvc -n s13-volumes
```

![12-apply-pvc-bound](01-kubernetes-volumes/screenshots/12-apply-pvc-bound.png)

### 13-describe-pvc

```bash
kubectl describe pvc static-pvc -n s13-volumes
```

![13-describe-pvc](01-kubernetes-volumes/screenshots/13-describe-pvc.png)

### 14-pvc-pod-write

```bash
kubectl apply -f 05-pvc-pod.yaml && kubectl wait --for=condition=Ready pod/static-storage-demo -n s13-volumes --timeout=120s && kubectl exec static-storage-demo -n s13-volumes -- sh -c "echo student-data-on-static-pv > /data/student.txt && cat /data/student.txt"
```

![14-pvc-pod-write](01-kubernetes-volumes/screenshots/14-pvc-pod-write.png)

### 15-pvc-pod-delete-recreate

```bash
kubectl delete pod static-storage-demo -n s13-volumes && kubectl apply -f 05-pvc-pod.yaml && kubectl wait --for=condition=Ready pod/static-storage-demo -n s13-volumes --timeout=120s && kubectl exec static-storage-demo -n s13-volumes -- cat /data/student.txt
```

![15-pvc-pod-delete-recreate](01-kubernetes-volumes/screenshots/15-pvc-pod-delete-recreate.png)

### 16-storageclass

```bash
kubectl get storageclass && kubectl describe storageclass standard
```

![16-storageclass](01-kubernetes-volumes/screenshots/16-storageclass.png)

### 17-dynamic-pvc

```bash
kubectl apply -f 06-dynamic-pvc.yaml && sleep 5 && kubectl get pvc dynamic-pvc -n s13-volumes && kubectl get pv
```

![17-dynamic-pvc](01-kubernetes-volumes/screenshots/17-dynamic-pvc.png)

### 18-dynamic-pvc-describe

```bash
kubectl describe pvc dynamic-pvc -n s13-volumes | tail -8
```

![18-dynamic-pvc-describe](01-kubernetes-volumes/screenshots/18-dynamic-pvc-describe.png)

### 19-dynamic-deploy-write

```bash
kubectl apply -f 07-dynamic-deployment.yaml && kubectl rollout status deployment/dynamic-storage-app -n s13-volumes --timeout=120s && POD=$(kubectl get pod -n s13-volumes -l app=dynamic-storage-app -o jsonpath="{.items[0].metadata.name}") && echo "pod: $POD" && kubectl exec $POD -n s13-volumes -- sh -c "echo order-123-saved-at-$(date +%H:%M:%S) > /data/orders.txt && cat /data/orders.txt"
```

![19-dynamic-deploy-write](01-kubernetes-volumes/screenshots/19-dynamic-deploy-write.png)

### 20-dynamic-delete-pod-data-survives

```bash
OLD=$(kubectl get pod -n s13-volumes -l app=dynamic-storage-app -o jsonpath="{.items[0].metadata.name}") && kubectl delete pod $OLD -n s13-volumes && kubectl rollout status deployment/dynamic-storage-app -n s13-volumes --timeout=120s && NEW=$(kubectl get pod -n s13-volumes -l app=dynamic-storage-app --field-selector=status.phase=Running -o jsonpath="{.items[0].metadata.name}") && echo "old pod: $O ...
```

![20-dynamic-delete-pod-data-survives](01-kubernetes-volumes/screenshots/20-dynamic-delete-pod-data-survives.png)

### 21-all-storage

```bash
kubectl get pv && kubectl get pvc,pods -n s13-volumes -o wide
```

![21-all-storage](01-kubernetes-volumes/screenshots/21-all-storage.png)

### 22-reclaim-policy

```bash
kubectl delete namespace s13-volumes && sleep 5 && kubectl get pv
```

![22-reclaim-policy](01-kubernetes-volumes/screenshots/22-reclaim-policy.png)

### 23-cleanup-static-pv

```bash
kubectl delete pv s13-static-pv && kubectl get pv
```

![23-cleanup-static-pv](01-kubernetes-volumes/screenshots/23-cleanup-static-pv.png)

## 02-hpa

### 01-deploy-app-and-hpa

```bash
kubectl apply -f hpa.yml
```

![01-deploy-app-and-hpa](02-hpa/screenshots/01-deploy-app-and-hpa.png)

### 02-rollout

```bash
kubectl rollout status deployment/yatri-backend -n s13-hpa-demo --timeout=180s && kubectl get deploy,svc,hpa,pods -n s13-hpa-demo -o wide
```

![02-rollout](02-hpa/screenshots/02-rollout.png)

### 03-before-get-hpa

```bash
kubectl get hpa -n s13-hpa-demo
```

![03-before-get-hpa](02-hpa/screenshots/03-before-get-hpa.png)

### 04-before-top-pods

```bash
kubectl top pods -n s13-hpa-demo
```

![04-before-top-pods](02-hpa/screenshots/04-before-top-pods.png)

### 05-before-get-pods

```bash
kubectl get pods -n s13-hpa-demo -o wide
```

![05-before-get-pods](02-hpa/screenshots/05-before-get-pods.png)

### 06-before-describe-hpa

```bash
kubectl describe hpa yatri-backend-hpa -n s13-hpa-demo
```

![06-before-describe-hpa](02-hpa/screenshots/06-before-describe-hpa.png)

### 07-verify-service

```bash
kubectl run curl-test -n s13-hpa-demo --rm -i --restart=Never --image=curlimages/curl:8.6.0 -- sh -c "time curl -s http://yatri-backend-service"
```

![07-verify-service](02-hpa/screenshots/07-verify-service.png)

### 08-start-load-generator

```bash
./load_generator.sh start 3
```

![08-start-load-generator](02-hpa/screenshots/08-start-load-generator.png)

### 09-load-generator-pods

```bash
sleep 20; kubectl get pods -n s13-hpa-demo -l app=load-generator; kubectl logs -n s13-hpa-demo deploy/load-generator --tail=3
```

![09-load-generator-pods](02-hpa/screenshots/09-load-generator-pods.png)

### 10-during-1

```bash
date +%T; kubectl get hpa -n s13-hpa-demo; echo; kubectl top pods -n s13-hpa-demo -l app=yatri-backend; echo; kubectl get pods -n s13-hpa-demo -l app=yatri-backend
```

![10-during-1](02-hpa/screenshots/10-during-1.png)

### 10-during-2

```bash
date +%T; kubectl get hpa -n s13-hpa-demo; echo; kubectl top pods -n s13-hpa-demo -l app=yatri-backend; echo; kubectl get pods -n s13-hpa-demo -l app=yatri-backend
```

![10-during-2](02-hpa/screenshots/10-during-2.png)

### 10-during-3

```bash
date +%T; kubectl get hpa -n s13-hpa-demo; echo; kubectl top pods -n s13-hpa-demo -l app=yatri-backend; echo; kubectl get pods -n s13-hpa-demo -l app=yatri-backend
```

![10-during-3](02-hpa/screenshots/10-during-3.png)

### 10-during-4

```bash
date +%T; kubectl get hpa -n s13-hpa-demo; echo; kubectl top pods -n s13-hpa-demo -l app=yatri-backend; echo; kubectl get pods -n s13-hpa-demo -l app=yatri-backend
```

![10-during-4](02-hpa/screenshots/10-during-4.png)

### 10-during-5

```bash
date +%T; kubectl get hpa -n s13-hpa-demo; echo; kubectl top pods -n s13-hpa-demo -l app=yatri-backend; echo; kubectl get pods -n s13-hpa-demo -l app=yatri-backend
```

![10-during-5](02-hpa/screenshots/10-during-5.png)

### 10-during-6

```bash
date +%T; kubectl get hpa -n s13-hpa-demo; echo; kubectl top pods -n s13-hpa-demo -l app=yatri-backend; echo; kubectl get pods -n s13-hpa-demo -l app=yatri-backend
```

![10-during-6](02-hpa/screenshots/10-during-6.png)

### 10-during-7

```bash
date +%T; kubectl get hpa -n s13-hpa-demo; echo; kubectl top pods -n s13-hpa-demo -l app=yatri-backend; echo; kubectl get pods -n s13-hpa-demo -l app=yatri-backend
```

![10-during-7](02-hpa/screenshots/10-during-7.png)

### 10-during-8

```bash
date +%T; kubectl get hpa -n s13-hpa-demo; echo; kubectl top pods -n s13-hpa-demo -l app=yatri-backend; echo; kubectl get pods -n s13-hpa-demo -l app=yatri-backend
```

![10-during-8](02-hpa/screenshots/10-during-8.png)

### 10-during-9

```bash
date +%T; kubectl get hpa -n s13-hpa-demo; echo; kubectl top pods -n s13-hpa-demo -l app=yatri-backend; echo; kubectl get pods -n s13-hpa-demo -l app=yatri-backend
```

![10-during-9](02-hpa/screenshots/10-during-9.png)

### 11-during-describe-hpa

```bash
kubectl describe hpa yatri-backend-hpa -n s13-hpa-demo
```

![11-during-describe-hpa](02-hpa/screenshots/11-during-describe-hpa.png)

### 12-during-top-node

```bash
kubectl top pods -n s13-hpa-demo; kubectl get deploy yatri-backend -n s13-hpa-demo
```

![12-during-top-node](02-hpa/screenshots/12-during-top-node.png)

### 13-stop-load-generator

```bash
./load_generator.sh stop
```

![13-stop-load-generator](02-hpa/screenshots/13-stop-load-generator.png)

### 14-after-1

```bash
date +%T; kubectl get hpa -n s13-hpa-demo; echo; kubectl top pods -n s13-hpa-demo -l app=yatri-backend; echo; kubectl get pods -n s13-hpa-demo -l app=yatri-backend
```

![14-after-1](02-hpa/screenshots/14-after-1.png)

### 14-after-2

```bash
date +%T; kubectl get hpa -n s13-hpa-demo; echo; kubectl top pods -n s13-hpa-demo -l app=yatri-backend; echo; kubectl get pods -n s13-hpa-demo -l app=yatri-backend
```

![14-after-2](02-hpa/screenshots/14-after-2.png)

### 15-after-scaled-down

```bash
date +%T; kubectl get hpa -n s13-hpa-demo; echo; kubectl top pods -n s13-hpa-demo; echo; kubectl get pods -n s13-hpa-demo
```

![15-after-scaled-down](02-hpa/screenshots/15-after-scaled-down.png)

## 03-probes

### 01-apply-healthy-probes

```bash
kubectl apply -f 00-namespace.yaml -f 01-liveness.yaml -f 02-readiness.yaml -f 03-startup.yaml
```

![01-apply-healthy-probes](03-probes/screenshots/01-apply-healthy-probes.png)

### 02-wait-healthy

```bash
kubectl wait --for=condition=Ready pod --all -n s13-probes --timeout=180s; kubectl get pods -n s13-probes
```

![02-wait-healthy](03-probes/screenshots/02-wait-healthy.png)

### 03-describe-liveness

```bash
kubectl describe pod liveness-demo -n s13-probes | grep -E "Liveness|Readiness|Startup|State|Ready|Restart Count"
```

![03-describe-liveness](03-probes/screenshots/03-describe-liveness.png)

### 04-describe-startup

```bash
kubectl describe pod startup-demo -n s13-probes | grep -E "Liveness|Readiness|Startup|Restart Count"
```

![04-describe-startup](03-probes/screenshots/04-describe-startup.png)

### 05-apply-failing-probes

```bash
kubectl apply -f 04-liveness-fail.yaml -f 05-readiness-fail.yaml -f 06-slow-startup.yaml
```

![05-apply-failing-probes](03-probes/screenshots/05-apply-failing-probes.png)

### 06-slow-startup-not-ready

```bash
sleep 8; kubectl get pod slow-startup-demo -n s13-probes; kubectl describe pod slow-startup-demo -n s13-probes | grep -E "Startup probe failed" | tail -2
```

![06-slow-startup-not-ready](03-probes/screenshots/06-slow-startup-not-ready.png)

### 07-slow-startup-ready

```bash
kubectl get pod slow-startup-demo -n s13-probes; kubectl logs slow-startup-demo -n s13-probes
```

![07-slow-startup-ready](03-probes/screenshots/07-slow-startup-ready.png)

### 08-liveness-fail-restarts

```bash
kubectl get pods liveness-fail-demo readiness-fail-demo -n s13-probes
```

![08-liveness-fail-restarts](03-probes/screenshots/08-liveness-fail-restarts.png)

### 09-slow-startup-events

```bash
kubectl get pod slow-startup-demo -n s13-probes; kubectl events -n s13-probes --for pod/slow-startup-demo
```

![09-slow-startup-events](03-probes/screenshots/09-slow-startup-events.png)

### 10-liveness-fail-events

```bash
kubectl events -n s13-probes --for pod/liveness-fail-demo | tail -8
```

![10-liveness-fail-events](03-probes/screenshots/10-liveness-fail-events.png)

### 11-readiness-fail-events

```bash
kubectl events -n s13-probes --for pod/readiness-fail-demo | tail -4
```

![11-readiness-fail-events](03-probes/screenshots/11-readiness-fail-events.png)

### 12-endpoints-compare

```bash
kubectl get endpointslices -n s13-probes; echo; kubectl describe svc readiness-fail-svc -n s13-probes | grep -i endpoints; kubectl describe svc readiness-demo-svc -n s13-probes | grep -i endpoints
```

![12-endpoints-compare](03-probes/screenshots/12-endpoints-compare.png)

### 12b-endpointslice-conditions

```bash
kubectl get endpointslices -n s13-probes -o custom-columns=NAME:.metadata.name,SERVICE:.metadata.labels.kubernetes\.io/service-name,IP:.endpoints[*].addresses[0],READY:.endpoints[*].conditions.ready
```

![12b-endpointslice-conditions](03-probes/screenshots/12b-endpointslice-conditions.png)

### 13-all-probe-pods

```bash
kubectl get pods -n s13-probes -o wide
```

![13-all-probe-pods](03-probes/screenshots/13-all-probe-pods.png)

### 14-liveness-fail-restarts-later

```bash
kubectl get pod liveness-fail-demo -n s13-probes; kubectl describe pod liveness-fail-demo -n s13-probes | grep -E "Restart Count|Last State|Reason"
```

![14-liveness-fail-restarts-later](03-probes/screenshots/14-liveness-fail-restarts-later.png)

### 15-final-state

```bash
kubectl get pods -n s13-probes; kubectl get pod liveness-fail-demo -n s13-probes -o jsonpath="liveness-fail-demo restartCount={.status.containerStatuses[0].restartCount}"; echo
```

![15-final-state](03-probes/screenshots/15-final-state.png)

### 16-cleanup

```bash
kubectl delete namespace s13-probes --wait=false
```

![16-cleanup](03-probes/screenshots/16-cleanup.png)

## mini-project

### 01-namespace

```bash
kubectl apply -f namespace.yaml
```

![01-namespace](mini-project/screenshots/01-namespace.png)

### 02-pvc

```bash
kubectl apply -f pvc.yaml && sleep 5 && kubectl get pvc -n production-webapp
```

![02-pvc](mini-project/screenshots/02-pvc.png)

### 03-deploy-and-service

```bash
kubectl apply -f deployment.yaml && kubectl apply -f service.yaml && kubectl rollout status deployment/web-app -n production-webapp --timeout=240s && kubectl get pods -n production-webapp -o wide
```

![03-deploy-and-service](mini-project/screenshots/03-deploy-and-service.png)

### 04-hpa

```bash
kubectl apply -f hpa.yaml && kubectl get hpa -n production-webapp
```

![04-hpa](mini-project/screenshots/04-hpa.png)

### 05-get-all

```bash
kubectl get all,pvc -n production-webapp
```

![05-get-all](mini-project/screenshots/05-get-all.png)

### 06-describe-pod-probes

```bash
kubectl describe pod -n production-webapp -l app=web-app | grep -E "^Name:|Liveness|Readiness|Startup|Requests|Limits|cpu|memory|/data|ClaimName" | head -20
```

![06-describe-pod-probes](mini-project/screenshots/06-describe-pod-probes.png)

### 07-endpoints

```bash
kubectl describe svc web-service -n production-webapp | grep -E "Selector|TargetPort|Endpoints"
```

![07-endpoints](mini-project/screenshots/07-endpoints.png)

### 08-write-student-file

```bash
POD_NAME=$(kubectl get pods -n production-webapp -l app=web-app -o jsonpath="{.items[0].metadata.name}"); echo "pod: $POD_NAME"; kubectl exec -n production-webapp "$POD_NAME" -- sh -c "echo \"Student: Tanish Kothari\" > /data/student.txt"; kubectl exec -n production-webapp "$POD_NAME" -- cat /data/student.txt
```

![08-write-student-file](mini-project/screenshots/08-write-student-file.png)

### 09-delete-pod

```bash
POD_NAME=$(kubectl get pods -n production-webapp -l app=web-app -o jsonpath="{.items[0].metadata.name}"); kubectl delete pod -n production-webapp "$POD_NAME"; sleep 3; kubectl get pods -n production-webapp
```

![09-delete-pod](mini-project/screenshots/09-delete-pod.png)

### 10-data-survives

```bash
kubectl rollout status deployment/web-app -n production-webapp --timeout=180s; kubectl wait --for=condition=Ready pod -l app=web-app -n production-webapp --timeout=180s; kubectl get pods -n production-webapp; for p in $(kubectl get pods -n production-webapp -l app=web-app -o jsonpath="{.items[*].metadata.name}"); do echo "--- $p"; kubectl exec -n production-webapp $p -- cat /data/student.txt; done ...
```

![10-data-survives](mini-project/screenshots/10-data-survives.png)

### 11-port-forward-curl

```bash
(kubectl port-forward -n production-webapp svc/web-service 18080:80 >/tmp/pf-s13.log 2>&1 &) ; sleep 4; curl -s http://localhost:18080 | head -6; pkill -f "port-forward -n production-webapp svc/web-service 18080:80"; cat /tmp/pf-s13.log
```

![11-port-forward-curl](mini-project/screenshots/11-port-forward-curl.png)

### 12-hpa-baseline

```bash
kubectl get hpa -n production-webapp; kubectl top pods -n production-webapp
```

![12-hpa-baseline](mini-project/screenshots/12-hpa-baseline.png)

### 13-start-load

```bash
kubectl run load-generator -n production-webapp --image=busybox:1.36 --restart=Never -- /bin/sh -c "while true; do wget -q -O- http://web-service > /dev/null; done"; sleep 5; kubectl get pod load-generator -n production-webapp
```

![13-start-load](mini-project/screenshots/13-start-load.png)

### 14-hpa-during-load

```bash
date +%T; kubectl get hpa -n production-webapp; kubectl get pods -n production-webapp; kubectl top pods -n production-webapp; kubectl -n kube-system get pods -l k8s-app=metrics-server; kubectl describe hpa web-app-hpa -n production-webapp | grep -A4 "^Conditions:"
```

![14-hpa-during-load](mini-project/screenshots/14-hpa-during-load.png)

### 15-stop-load

```bash
kubectl delete pod load-generator -n production-webapp --wait=false
```

![15-stop-load](mini-project/screenshots/15-stop-load.png)

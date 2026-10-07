# Session 21: Final DevOps Project & Troubleshooting

> Work in progress: the full write-up for this session is being finalised. Every screenshot below is real output from commands run on a local minikube cluster / Docker / GitHub Actions.

## Evidence

### 01-pytest-coverage

```bash
cd application/backend && pytest -v
```

![01-pytest-coverage](screenshots/01-pytest-coverage.png)

### 02-frontend-test-build

```bash
cd application/frontend && npm ci --no-audit --no-fund && npm test && npm run build
```

![02-frontend-test-build](screenshots/02-frontend-test-build.png)

### 03-docker-build-backend

```bash
docker build --progress=plain -t stockpilot-backend:local application/backend 2>&1 | grep -E '^#[0-9]+ (\[|DONE|naming|writing)|FROM|ERROR' | tail -40
```

![03-docker-build-backend](screenshots/03-docker-build-backend.png)

### 04-docker-build-frontend

```bash
docker build --progress=plain -t stockpilot-frontend:local application/frontend 2>&1 | grep -E '^#[0-9]+ (\[|DONE|naming|writing)|FROM|ERROR|built in' | tail -40
```

![04-docker-build-frontend](screenshots/04-docker-build-frontend.png)

### 05-docker-compose-up

```bash
cd docker && docker compose up --build -d 2>&1 | grep -vE '^#|^ *$' | tail -25
```

![05-docker-compose-up](screenshots/05-docker-compose-up.png)

### 06-docker-compose-ps

```bash
cd docker && docker compose ps && docker compose logs backend --tail 8
```

![06-docker-compose-ps](screenshots/06-docker-compose-ps.png)

### 07-compose-seed-and-curl

```bash
BASE_URL=http://localhost:3000 ./scripts/seed.sh && curl -s localhost:8010/health && echo && curl -s localhost:8010/ready && echo && curl -s localhost:3000/api/info && echo && curl -s localhost:3000/api/stats | jq . && curl -s 'localhost:3000/api/items?low_stock=true' | jq -c '.[] | {sku,name,quantity,reorder_level,low_stock}'
```

![07-compose-seed-and-curl](screenshots/07-compose-seed-and-curl.png)

### 08-compose-crud-api

```bash
API=localhost:8010/api; curl -s -X POST $API/items -H 'Content-Type: application/json' -d '{"sku":"TMP-001","name":"Demo item","quantity":3,"reorder_level":1,"unit_price":10}' | jq -c '{id,sku,quantity}'; ID=$(curl -s $API/items?q=TMP | jq '.[0].id'); curl -s $API/items/$ID | jq -c '{id,sku,name,location}'; curl -s -X PUT $API/items/$ID -H 'Content-Type: application/json' -d '{"location":"Z-99"}'  ...
```

![08-compose-crud-api](screenshots/08-compose-crud-api.png)

### 09-ui-desktop-compose

![09-ui-desktop-compose](screenshots/09-ui-desktop-compose.png)

### 10-ui-mobile-compose

![10-ui-mobile-compose](screenshots/10-ui-mobile-compose.png)

### 11-fastapi-docs

![11-fastapi-docs](screenshots/11-fastapi-docs.png)

### 12-compose-postgres-tables

```bash
cd docker && docker compose exec -T postgres psql -U stockpilot -d stockpilot -c '\dt' -c 'select * from alembic_version;' -c 'select sku, name, quantity, reorder_level from items order by sku;' && docker compose exec -T backend id
```

![12-compose-postgres-tables](screenshots/12-compose-postgres-tables.png)

### 13-minikube-image-load

```bash
minikube image load stockpilot-backend:local && minikube image load stockpilot-frontend:local && minikube image ls | grep -E 'stockpilot|postgres:16'
```

![13-minikube-image-load](screenshots/13-minikube-image-load.png)

### 14-kubectl-apply-manifests

```bash
kubectl apply -f kubernetes/namespace.yaml && kubectl apply -k kubernetes/ && kubectl rollout status deploy/stockpilot-backend -n taskboard --timeout=240s && kubectl rollout status deploy/stockpilot-frontend -n taskboard --timeout=120s
```

![14-kubectl-apply-manifests](screenshots/14-kubectl-apply-manifests.png)

### 15-k8s-manifests-resources

```bash
kubectl get all,ing,hpa,pvc,cm,secret -n taskboard
```

![15-k8s-manifests-resources](screenshots/15-k8s-manifests-resources.png)

### 16-k8s-manifests-ingress-curl

```bash
BASE_URL=http://localhost:8082 HOST_HEADER=stockpilot.local ./scripts/seed.sh && curl -s -H 'Host: stockpilot.local' localhost:8082/api/info && echo && curl -s -H 'Host: stockpilot.local' localhost:8082/api/stats | jq -c . && curl -s -o /dev/null -w 'GET / (frontend via ingress) -> %{http_code}\n' -H 'Host: stockpilot.local' localhost:8082/
```

![16-k8s-manifests-ingress-curl](screenshots/16-k8s-manifests-ingress-curl.png)

### 17-kubectl-delete-manifests

```bash
kubectl delete -k kubernetes/ --wait=true && kubectl get all -n taskboard
```

![17-kubectl-delete-manifests](screenshots/17-kubectl-delete-manifests.png)

### 18-helm-lint-template

```bash
helm lint helm/stockpilot -f helm/stockpilot/values-local.yaml && helm template stockpilot helm/stockpilot -n taskboard -f helm/stockpilot/values-local.yaml | grep -E '^kind:' | sort | uniq -c
```

![18-helm-lint-template](screenshots/18-helm-lint-template.png)

### 19-helm-install

```bash
helm upgrade --install stockpilot helm/stockpilot -n taskboard -f helm/stockpilot/values-local.yaml --wait --timeout 6m
```

![19-helm-install](screenshots/19-helm-install.png)

### 20-helm-list-and-test

```bash
helm list -n taskboard && helm test stockpilot -n taskboard --logs
```

![20-helm-list-and-test](screenshots/20-helm-list-and-test.png)

### 21-helm-k8s-resources

```bash
kubectl get all,ing,hpa,pvc,cm,secret -n taskboard -o wide
```

![21-helm-k8s-resources](screenshots/21-helm-k8s-resources.png)

### 22-helm-ingress-curl

```bash
BASE_URL=http://localhost:8082 HOST_HEADER=stockpilot.local ./scripts/seed.sh; kubectl get ingress stockpilot -n taskboard && curl -s -H 'Host: stockpilot.local' localhost:8082/api/info && echo && curl -s -H 'Host: stockpilot.local' 'localhost:8082/api/items?low_stock=true' | jq -c '.[] | {sku,quantity,reorder_level}' && curl -s -H 'Host: stockpilot.local' localhost:8082/ | head -c 300; echo
```

![22-helm-ingress-curl](screenshots/22-helm-ingress-curl.png)

### 23-ui-via-ingress-desktop

![23-ui-via-ingress-desktop](screenshots/23-ui-via-ingress-desktop.png)

### 24-ui-via-ingress-mobile

![24-ui-via-ingress-mobile](screenshots/24-ui-via-ingress-mobile.png)

### 25-k8s-probes-config

```bash
kubectl get deploy stockpilot-backend -n taskboard -o json | jq '.spec.template.spec.containers[0] | {image, envFrom, startupProbe, readinessProbe, livenessProbe, resources, securityContext}' && kubectl get configmap stockpilot-config -n taskboard -o jsonpath='{.data}' | jq -c . && kubectl get secret stockpilot-db -n taskboard -o json | jq -c '.data | map_values("<redacted base64>")'
```

![25-k8s-probes-config](screenshots/25-k8s-probes-config.png)

### 26-pvc-persistence

```bash
curl -s -H 'Host: stockpilot.local' localhost:8082/api/stats | jq -c '{total_skus,total_units}' && kubectl delete pod stockpilot-postgres-0 -n taskboard && sleep 5 && kubectl get pods -n taskboard && curl -s -o /dev/null -w 'API while the DB pod restarts -> HTTP %{http_code}\n' -H 'Host: stockpilot.local' localhost:8082/api/stats; kubectl wait --for=condition=Ready pod/stockpilot-postgres-0 -n tas ...
```

![26-pvc-persistence](screenshots/26-pvc-persistence.png)

### 27-sast-bandit

```bash
cd application/backend && bandit -c ../../security/bandit.yaml -r app alembic -f json -o ../../security/reports/bandit.json --exit-zero -q; bandit -c ../../security/bandit.yaml -r app alembic --severity-level medium --confidence-level medium
```

![27-sast-bandit](screenshots/27-sast-bandit.png)

### 28-sast-semgrep

```bash
semgrep scan --metrics=off --error --config p/python --config p/javascript --config p/react --config p/dockerfile --json-output=security/reports/semgrep.json application/backend/app application/backend/alembic application/frontend/src application/backend/Dockerfile application/frontend/Dockerfile 2>&1 | tail -30
```

![28-sast-semgrep](screenshots/28-sast-semgrep.png)

### 29-sca-pip-audit

```bash
pip-audit -r application/backend/requirements.txt --strict --progress-spinner off -f json -o security/reports/pip-audit.json; pip-audit -r application/backend/requirements.txt --strict --progress-spinner off --desc on
```

![29-sca-pip-audit](screenshots/29-sca-pip-audit.png)

### 30-sca-npm-audit

```bash
cd application/frontend && npm audit --audit-level=high && npm audit --json > ../../security/reports/npm-audit.json; jq '.metadata.vulnerabilities' ../../security/reports/npm-audit.json
```

![30-sca-npm-audit](screenshots/30-sca-npm-audit.png)

### 31-sca-trivy-fs

```bash
trivy fs --quiet --scanners vuln,secret --severity HIGH,CRITICAL --ignore-unfixed --skip-dirs application/frontend/node_modules --exit-code 1 --format json --output security/reports/trivy-fs.json . ; echo "exit code: $?"; trivy fs --quiet --scanners vuln,secret --severity HIGH,CRITICAL --ignore-unfixed --skip-dirs application/frontend/node_modules --exit-code 1 .
```

![31-sca-trivy-fs](screenshots/31-sca-trivy-fs.png)

### 32-secrets-gitleaks

```bash
gitleaks dir . --config security/.gitleaks.toml --redact --no-banner --report-format json --report-path security/reports/gitleaks-dir.json; echo "dir scan exit code: $?"; gitleaks git ../.. --config security/.gitleaks.toml --redact --no-banner --log-opts='-- DevOps-main/final-devops-project' --report-format json --report-path security/reports/gitleaks-history.json; echo "git history scan exit code ...
```

![32-secrets-gitleaks](screenshots/32-secrets-gitleaks.png)

### 33-trivy-image-backend-before-fix

```bash
trivy image --quiet --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 --format json --output security/reports/trivy-backend-before-fix.json stockpilot-backend:before-fix; echo "security gate exit code: $? (1 = FAIL)"; jq -r '.Results[] | select(.Vulnerabilities) | .Vulnerabilities[] | [.PkgName, .InstalledVersion, .FixedVersion, .VulnerabilityID, .Severity] | @tsv' security/reports/trivy-bac ...
```

![33-trivy-image-backend-before-fix](screenshots/33-trivy-image-backend-before-fix.png)

### 34-trivy-image-backend-after-fix

```bash
trivy image --quiet --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 --format json --output security/reports/trivy-backend.json stockpilot-backend:local; echo "security gate exit code: $? (0 = PASS)"; jq -r '[.Results[] | (.Vulnerabilities // []) | length] | add | "HIGH/CRITICAL fixable findings: \(.)"' security/reports/trivy-backend.json; trivy image --quiet --severity HIGH,CRITICAL --form ...
```

![34-trivy-image-backend-after-fix](screenshots/34-trivy-image-backend-after-fix.png)

### 35-trivy-image-frontend

```bash
trivy image --quiet --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 --format json --output security/reports/trivy-frontend.json stockpilot-frontend:local; echo "security gate exit code: $? (0 = PASS)"; trivy image --quiet --severity HIGH,CRITICAL --ignore-unfixed stockpilot-frontend:local
```

![35-trivy-image-frontend](screenshots/35-trivy-image-frontend.png)

### 36-actionlint-workflow

```bash
docker run --rm -v "$PWD:/repo" --workdir /repo rhysd/actionlint:latest .github/workflows/final-devops-project.yml && echo 'actionlint: no problems found' && grep -E '^  [a-z-]+:$|name: "[0-9]' .github/workflows/final-devops-project.yml
```

![36-actionlint-workflow](screenshots/36-actionlint-workflow.png)

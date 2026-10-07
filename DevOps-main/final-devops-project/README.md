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

### 12b-compose-down

```bash
cd docker && docker compose down && docker compose ps -a && docker volume ls | grep stockpilot
```

![12b-compose-down](screenshots/12b-compose-down.png)

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

### 37-terraform-init

```bash
cd terraform && terraform init -input=false
```

![37-terraform-init](screenshots/37-terraform-init.png)

### 38-terraform-fmt-validate

```bash
cd terraform && terraform fmt -recursive -check -diff && echo 'terraform fmt: all files formatted' && terraform validate
```

![38-terraform-fmt-validate](screenshots/38-terraform-fmt-validate.png)

### 39-terraform-plan-eks-preview

```bash
cd terraform && terraform plan -input=false -var-file=localstack.tfvars -var use_localstack=true -var enable_eks=true -var enable_ecr=true -var enable_k3s_node=false -no-color | grep -E '^  # |^Plan:'
```

![39-terraform-plan-eks-preview](screenshots/39-terraform-plan-eks-preview.png)

### 40-terraform-plan-localstack

```bash
cd terraform && terraform plan -input=false -var-file=localstack.tfvars -out=localstack.tfplan -no-color | grep -E '^  # |^Plan:|Saved the plan'
```

![40-terraform-plan-localstack](screenshots/40-terraform-plan-localstack.png)

### 41-terraform-apply-localstack

```bash
cd terraform && terraform apply -input=false -auto-approve localstack.tfplan -no-color | grep -E 'Creation complete|Apply complete|Error'
```

![41-terraform-apply-localstack](screenshots/41-terraform-apply-localstack.png)

### 42-terraform-output

```bash
cd terraform && terraform output
```

![42-terraform-output](screenshots/42-terraform-output.png)

### 43-terraform-state-list

```bash
cd terraform && terraform state list
```

![43-terraform-state-list](screenshots/43-terraform-state-list.png)

### 44-localstack-verify-aws-cli

```bash
export AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=ap-south-1; A='aws --endpoint-url http://localhost:4566'; $A ec2 describe-vpcs --filters Name=tag:Project,Values=stockpilot --query 'Vpcs[].[VpcId,CidrBlock,Tags[?Key==`Name`]|[0].Value]' --output table && $A ec2 describe-subnets --filters Name=tag:Project,Values=stockpilot --query 'Subnets[].[SubnetId,CidrBlock,Availabili ...
```

![44-localstack-verify-aws-cli](screenshots/44-localstack-verify-aws-cli.png)

### 45-terraform-plan-after-apply

```bash
cd terraform && terraform plan -input=false -var-file=localstack.tfvars -no-color -detailed-exitcode | grep -E '^  # |^Plan:|No changes|~ |http_tokens'; echo "plan exit code: ${PIPESTATUS[0]}"
```

![45-terraform-plan-after-apply](screenshots/45-terraform-plan-after-apply.png)

### 46-terraform-destroy

```bash
cd terraform && terraform destroy -input=false -auto-approve -var-file=localstack.tfvars -no-color | grep -E 'Destruction complete|Destroy complete|Error' | tail -12 && terraform state list | wc -l | xargs echo 'resources left in state:'
```

![46-terraform-destroy](screenshots/46-terraform-destroy.png)

### 47-trivy-config-iac-after

```bash
trivy config --quiet --severity HIGH,CRITICAL --format json --output security/reports/trivy-config.json . ; jq -r '[.Results[]? | .Misconfigurations // [] | .[] | select(.Status=="FAIL")] | length | "HIGH/CRITICAL misconfigurations: \(.)"' security/reports/trivy-config.json; jq -r '[.Results[]? | select(.Misconfigurations) | .Target] | unique | .[]' security/reports/trivy-config.json | sed 's/^/sc ...
```

![47-trivy-config-iac-after](screenshots/47-trivy-config-iac-after.png)

### 47-trivy-config-iac-before

```bash
trivy config --quiet --severity HIGH,CRITICAL --format json --output security/reports/trivy-config.json . ; trivy config --quiet --severity HIGH,CRITICAL . 2>&1 | grep -E 'Tests:|Failures:|^[A-Z]+ ?\(|AVD-|^\S+ \(' | head -40; jq -r '[.Results[]? | .Misconfigurations // [] | .[] | select(.Status=="FAIL")] | group_by(.ID) | map({id: .[0].ID, severity: .[0].Severity, title: .[0].Title, count: length ...
```

![47-trivy-config-iac-before](screenshots/47-trivy-config-iac-before.png)

### 48-helm-upgrade-postgres-hardening

```bash
helm upgrade stockpilot helm/stockpilot -n taskboard -f helm/stockpilot/values-local.yaml --wait --timeout 12m | head -7 && kubectl exec -n taskboard stockpilot-postgres-0 -- id && kubectl get sts stockpilot-postgres -n taskboard -o jsonpath='{.spec.template.spec.securityContext}{"\n"}{.spec.template.spec.containers[0].securityContext}{"\n"}' && kubectl get pods -n taskboard && curl -s -H 'Host: s ...
```

![48-helm-upgrade-postgres-hardening](screenshots/48-helm-upgrade-postgres-hardening.png)

### 49-ghcr-images

```bash
for img in stockpilot-backend stockpilot-frontend; do T=$(curl -s "https://ghcr.io/token?scope=repository:tanishkothari9/$img:pull" | jq -r .token); curl -s -H "Authorization: Bearer $T" https://ghcr.io/v2/tanishkothari9/$img/tags/list | jq -c .; done; docker pull ghcr.io/tanishkothari9/stockpilot-frontend:68adae859364a8653de35a9ab25473ae19baf14c | tail -2; docker images --format 'table {{.Reposit ...
```

![49-ghcr-images](screenshots/49-ghcr-images.png)

### 50-ghcr-package-page-backend

![50-ghcr-package-page-backend](screenshots/50-ghcr-package-page-backend.png)

### 51-gha-run-green-graph

![51-gha-run-green-graph](screenshots/51-gha-run-green-graph.png)

### 52-gha-run1-failed-gate-blocked

![52-gha-run1-failed-gate-blocked](screenshots/52-gha-run1-failed-gate-blocked.png)

### 53-ci-log-pytest

```bash
gh run view -R tanishkothari9/DevOps --log --job 112943750050 | cut -f3 | sed -E 's/^[0-9T:.Z-]+ //; s/\^\[\[[0-9;]*m//g; s/\x1b\[[0-9;]*m//g' | grep -E 'PASSED|passed in|TOTAL|^# (tests|pass|fail) [0-9]|built in|chart\(s\) linted' | head -30
```

![53-ci-log-pytest](screenshots/53-ci-log-pytest.png)

### 54-ci-log-trivy-image-scan

```bash
gh run view -R tanishkothari9/DevOps --log --job 112944043999 | cut -f3 | sed -E 's/^[0-9T:.Z-]+ //; s/\^\[\[[0-9;]*m//g; s/\x1b\[[0-9;]*m//g' | grep -E 'Report Summary|Target|stockpilot-(backend|frontend):|debian|alpine|Legend|Clean|naming to' | grep -vE 'METADATA|docker run' | head -40
```

![54-ci-log-trivy-image-scan](screenshots/54-ci-log-trivy-image-scan.png)

### 55-ci-log-security-gate

```bash
gh run view -R tanishkothari9/DevOps --log --job 112944563898 | cut -f3 | sed -E 's/^[0-9T:.Z-]+ //; s/\^\[\[[0-9;]*m//g; s/\x1b\[[0-9;]*m//g' | grep -E '^reports/|^Security gate passed|Download artifact has finished|Artifact image-scan-reports' | head -20
```

![55-ci-log-security-gate](screenshots/55-ci-log-security-gate.png)

### 56-ci-log-push-ghcr

```bash
gh run view -R tanishkothari9/DevOps --log --job 112944610323 | cut -f3 | sed -E 's/^[0-9T:.Z-]+ //' | grep -E 'Loaded image|digest:|== ghcr|Name:|Digest:|\{"name"|Login Succeeded' | head -20
```

![56-ci-log-push-ghcr](screenshots/56-ci-log-push-ghcr.png)

### 57-ci-log-deploy-kind

```bash
gh run view -R tanishkothari9/DevOps --log --job 112945080536 | cut -f3 | sed -E 's/^[0-9T:.Z-]+ //; s/\^\[\[[0-9;]*m//g; s/\x1b\[[0-9;]*m//g' | grep -E 'Creating cluster|Ready after|STATUS: deployed|successfully rolled out|Phase:|\{"status"|service"|ghcr.io/tanishkothari9|^pod/|^deployment.apps/|^persistentvolumeclaim/|^horizontalpodautoscaler' | grep -vE 'set |_IMAGE:' | cut -c1-180 | head -40
```

![57-ci-log-deploy-kind](screenshots/57-ci-log-deploy-kind.png)

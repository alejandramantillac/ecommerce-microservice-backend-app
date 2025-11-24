# Rollback Playbooks

These playbooks describe the exact actions, commands, and objectives to recover every service in case of incidents. All commands were exercised in **staging** using the current Jenkins pipelines (automatic rollback is also triggered on every failed deployment for staging and production).

## Global Strategy

1. **Detect**: Jenkins failure notification includes the impacted services and a link to the build logs.
2. **Trigger rollback**:
   - Automatically: `commonFunctions.rollbackServices` runs from the Jenkins `post { failure { … } }` block for staging and production, issuing `kubectl rollout undo` for every deployment in the release.
   - Manually (if necessary): use the commands below from your workstation or the Jenkins VM.
3. **Verify**: Confirm new ReplicaSets are healthy and traffic is restored. Observability dashboards plus functional smoke tests validate success.

> **Automation status**: The pipelines already perform *rolling* deployments. On failure Jenkins invokes `kubectl rollout undo` per service. This provides a fast rollback equivalent to blue/green (the previous ReplicaSet stays warm) and keeps RTO within the values defined below.

## Commands (per service)

All examples assume the kubeconfig for the target environment is stored at `${WORKSPACE}/.kube/<env>-config`. Replace `<service>` with the actual deployment name (they match the folder names).

```bash
# Rollback last revision
kubectl --kubeconfig=$KCFG rollout undo deployment/<service> -n <namespace>

# Rollback to a specific revision (optional)
kubectl --kubeconfig=$KCFG rollout history deployment/<service> -n <namespace>
kubectl --kubeconfig=$KCFG rollout undo deployment/<service> -n <namespace> --to-revision=<id>

# Verify
kubectl --kubeconfig=$KCFG get pods -n <namespace> -l app=<service>
kubectl --kubeconfig=$KCFG get deploy/<service> -n <namespace> -o wide
```

To undo the whole release in one command you can re-run the helper that Jenkins uses:

```bash
./jenkins/scripts/rollback-services.sh --kubeconfig $KCFG --namespace <namespace> --services "user-service,product-service,..."
```

(The helper is invoked automatically when the pipeline fails; keep it handy for manual runs.)

## Service Matrix (RTO/RPO)

| Service              | Criticality | RTO (Target) | RPO (Target) | Notes |
|----------------------|-------------|--------------|-------------|-------|
| `api-gateway`        | High        | ≤ 5 minutes  | Stateless    | Fronts every call; rollback is first priority. |
| `user-service`       | High        | ≤ 10 minutes | 5 minutes    | Uses in-memory H2; data loss confined to active pod. |
| `product-service`    | High        | ≤ 10 minutes | 5 minutes    | Same rollback procedure as user-service. |
| `favourite-service`  | Medium      | ≤ 15 minutes | 10 minutes   | Cache-only writes; acceptable to discard transient data. |
| `proxy-client`       | Medium      | ≤ 15 minutes | 10 minutes   | UI adapter; fallback is static site. |
| `service-discovery`  | High        | ≤ 5 minutes  | Stateless    | If Eureka fails, restart with previous revision immediately. |
| `zipkin`             | Low         | ≤ 30 minutes | 30 minutes   | Observability only; can stay down during major incidents. |

> RTO/RPO values reflect automated rollback tests in staging (see Jenkins job `security-scan` run #17 for the latest validation). Production inherits the same automation but includes manual approval after rollback completes.

## Environment-specific Playbooks

### Staging

1. Jenkins `Jenkinsfile.stage` provisions infrastructure and stores kubeconfig in `.kube/staging-config`.
2. On failure Jenkins calls `rollbackServices` automatically. To rerun manually:
   ```bash
   export KCFG=${WORKSPACE}/.kube/staging-config
   ./jenkins/scripts/rollback-services.sh --kubeconfig $KCFG --namespace staging --services "${CHANGED_SERVICES}"
   ```
3. Validation: run `make smoke-tests` or trigger the `Run Tests` stage manually; ensure API Gateway responds.

### Production

1. Kubeconfig path: `.kube/prod-config` (exported as `PROD_KUBE_CONFIG_PATH`).
2. On failure Jenkins performs rollback and notifies the release channel. A release engineer must confirm traffic health before re-opening the pipeline.
3. If rollback is triggered manually:
   ```bash
   export KCFG=${WORKSPACE}/.kube/prod-config
   ./jenkins/scripts/rollback-services.sh --kubeconfig $KCFG --namespace prod --services "${CHANGED_SERVICES}"
   ```
4. Post-rollback: update the Change Calendar entry (see `docs/change-management/change-calendar.md`) with actual RTO/RPO and lessons learned.

## Testing Rollback Commands

- Staging rollbacks are executed automatically on every failed deployment (latest: build `stage #112`). The commands listed above were validated there.
- Production rollbacks are triggered through the Jenkins `post { failure { … } }` block and have been dry-run using `kubectl rollout undo` against the production namespace with dummy revisions.

## Blue/Green & Canary Considerations

- Deployments keep the previous ReplicaSet for instant rollbacks (Kubernetes’ rolling-update strategy behaves as blue/green from the perspective of the pods involved).
- Canary releases can be simulated by deploying only a subset of services (set `CHANGED_SERVICES` to the canary list and route traffic via the API Gateway). Documentation is provided in `docs/change-management/rollback-procedures.md`.

Keep this document updated whenever a service adds stateful components or when RTO/RPO targets change. Use the RFC template to record any permanent adjustments to the rollback strategy.


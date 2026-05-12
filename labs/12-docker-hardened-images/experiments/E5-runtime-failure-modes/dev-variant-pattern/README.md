# Pattern 2: Dev-Variant Pattern

When ephemeral debug containers aren't enough (deep diagnosis, repeated
runs, or workflows that need an *actual shell inside the app container's
filesystem*), DHI provides `-dev` variants of each base image.

`dhi.io/python:3.13-dev` exists in the DHI catalog. It contains:
- Everything `dhi.io/python:3.13` has
- Plus `bash`, package manager, common debug utilities
- Same DHI signing chain, same SBOM attestation pattern

**Use it in dev, staging, integration testing. Never in production.**

The trust contract: dev variants are still cryptographically signed by
DHI — the trust chain is unchanged. What changes is the *attack surface*,
which is acceptable in environments that don't process customer data.

## The policy refinement

Our base policy (`policies/require-trusted-registry.yaml`) allows
`dhi.io/*` everywhere. That's too permissive for production: nothing
stops a developer from deploying `dhi.io/python:3.13-dev` to prod by
accident.

The refinement is `allow-dev-variants-in-dev.yaml` in this directory:
production namespaces accept `dhi.io/*:<version>` but reject any image
ending in `-dev`; development namespaces accept both.

This is the *vendor-neutral* pattern in action again: the policy doesn't
say "DHI". It says "image references matching `*-dev` only in namespaces
labelled environment=dev". Substitute Chainguard's `:latest-dev` or your
internal `:debug` tag — same enforcement, same audit story.

## How to deploy a -dev variant in a dev namespace

```bash
# 1. Create or label the dev namespace
kubectl create namespace dev-debug
kubectl label namespace dev-debug environment=dev

# 2. Apply the policy refinement
kubectl apply -f labs/12-docker-hardened-images/experiments/E5-runtime-failure-modes/dev-variant-pattern/allow-dev-variants-in-dev.yaml

# 3. Pre-load the -dev variant (same pattern as E3)
docker pull dhi.io/python:3.13-dev
docker save dhi.io/python:3.13-dev | \
  docker exec -i dhi-trust-control-plane-control-plane \
    ctr --namespace=k8s.io images import -

# 4. Deploy
kubectl apply -f labs/12-docker-hardened-images/experiments/E5-runtime-failure-modes/dev-variant-pattern/deploy-dev-variant.yaml

# 5. Exec into the dev-variant pod (it has a real shell!)
kubectl -n dev-debug exec -it dhi-app-dev -- bash
#  root@dhi-app-dev:/# python -c 'import flask; print(flask.__version__)'
#  3.1.3

# 6. Now try the same image in the default namespace (which is NOT labelled dev)
kubectl run dhi-prod-leak \
  --image=dhi.io/python:3.13-dev \
  --image-pull-policy=Never \
  --restart=Never
# Expected: REJECTED by require-trusted-registry — production accepts dhi.io/*
# but the refinement policy rejects *-dev suffixes outside dev namespaces.
```

## Why this matters operationally

Without this pattern, teams that need to debug live often resort to:

1. **SSH into the node**, run `docker exec`, install tools manually.
   Breaks the audit trail. Pollutes the application container. Lets the
   developer modify the image on disk.

2. **Roll a deployment back to an older "debuggable" image** (often a
   non-hardened image). Trust contract collapses. Production now runs a
   weaker image than the SBOM and signature would suggest.

3. **Rebuild and redeploy with debug tools temporarily**, intending to
   roll back later. The "temporary" change ends up persisting; the
   one-time debug build becomes the new baseline.

The dev-variant pattern eliminates all three. Production stays hardened.
Debug environments have visible, audited tooling. Teams stop fighting
the trust contract.

## The trade-off

You still need *somewhere* to test runtime fixes before deploying them
to prod. The dev-variant pattern says: that somewhere is a labelled
namespace with a different policy contract — not a different *image*.

That's a different mental model from "dev environments have looser
security." Dev environments here have *visibly different image
signatures*, *visibly different SBOM contents*, and *visibly different
admission policies*. Everything stays auditable.

## File layout

```
dev-variant-pattern/
├── README.md                          ← this file
├── allow-dev-variants-in-dev.yaml     ← Kyverno policy refinement
└── deploy-dev-variant.yaml            ← Example pod using -dev variant
```
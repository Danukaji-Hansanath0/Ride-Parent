# Create a helper script
cat > setup-k8s.sh <<'EOF'
#!/bin/bash
set -e

# 1. Base namespace
mkdir -p k8s/base
cat > k8s/base/namespace.yaml <<YAML
apiVersion: v1
kind: Namespace
meta
  name: ride-dev
YAML

cat > k8s/base/kustomization.yaml <<YAML
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- namespace.yaml
YAML

# 2. Minimal components
mkdir -p k8s/components/{deployment,service,ingress}

# deployment.yaml (generic)
cat > k8s/components/deployment/deployment.yaml <<YAML
apiVersion: apps/v1
kind: Deployment
meta
  name: SERVICE_NAME
spec:
  replicas: 1
  selector:
    matchLabels:
      app: SERVICE_NAME
  template:
    meta
      labels:
        app: SERVICE_NAME
    spec:
      containers:
      - name: app
        image: nginx:alpine  # ← placeholder; will patch per app
        ports:
        - containerPort: 80
YAML

cat > k8s/components/deployment/kustomization.yaml <<YAML
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- deployment.yaml
YAML

# service.yaml
cat > k8s/components/service/service.yaml <<YAML
apiVersion: v1
kind: Service
meta
  name: SERVICE_NAME
spec:
  selector:
    app: SERVICE_NAME
  ports:
  - port: 80
    targetPort: 80
YAML

cat > k8s/components/service/kustomization.yaml <<YAML
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- service.yaml
YAML

# ingress.yaml (for gateway + docs)
cat > k8s/components/ingress/ingress.yaml <<YAML
apiVersion: networking.k8s.io/v1
kind: Ingress
meta
  name: api-ingress
spec:
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: placeholder  # will patch
            port:
              number: 80
YAML

cat > k8s/components/ingress/kustomization.yaml <<YAML
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- ingress.yaml
YAML

# 3. Minimal per-app overlays (dev only for now)
SERVICES="auth-service booking-service gateway-service mail-service payment-service pricing-service user-service vehicle-service"
for svc in $SERVICES; do
  mkdir -p k8s/apps/$svc/{config,overlays/dev}

  # configmap (empty for now)
  cat > k8s/apps/$svc/config/configmap.yaml <<YAML
apiVersion: v1
kind: ConfigMap
meta
  name: $svc-config
YAML

  # dev overlay
  cat > k8s/apps/$svc/overlays/dev/kustomization.yaml <<YAML
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: ride-dev
resources:
- ../../../components/deployment
- ../../../components/service
- ../config/configmap.yaml
images:
- name: nginx:alpine
  newName: nginx
  newTag: alpine
patches:
- target:
    kind: Deployment
    name: SERVICE_NAME
  patch: |
    - op: replace
      path: /metadata/name
      value: $svc
    - op: replace
      path: /spec/template/spec/containers/0/image
      value: hashicorp/http-echo  # ← simple test app
    - op: add
      path: /spec/template/spec/containers/0/args
      value: ["-text", "$svc is live! 🚀"]
YAML

  # top-level kustomization
  cat > k8s/apps/$svc/kustomization.yaml <<YAML
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- overlays/dev
YAML
done

# 4. Centralized docs (Scalar static UI)
mkdir -p k8s/apps/swagger-ui/{config,overlays/dev}
cat > k8s/apps/swagger-ui/config/configmap.yaml <<'YAML'
apiVersion: v1
kind: ConfigMap
meta
  name: swagger-ui-files

  index.html: |
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8"/>
      <title>RideShare API Docs</title>
      <script src="https://cdn.jsdelivr.net/npm/@scalar/api-reference"></script>
    </head>
    <body style="margin:0">
      <script>
        const api = new ApiReference({
          spec: { url: 'https://petstore3.swagger.io/api/v3/openapi.json' }, // placeholder
          // Later: url: '/api-docs.json'
        })
        document.body.appendChild(api)
      </script>
    </body>
    </html>
YAML

cat > k8s/apps/swagger-ui/overlays/dev/kustomization.yaml <<YAML
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: ride-dev
resources:
- ../../../components/deployment
- ../../../components/service
- ../config/configmap.yaml
patches:
- target:
    kind: Deployment
    name: SERVICE_NAME
  patch: |
    - op: replace
      path: /metadata/name
      value: swagger-ui
    - op: replace
      path: /spec/template/spec/containers/0/image
      value: nginx:alpine
    - op: add
      path: /spec/template/spec/volumes
      value:
      - name: site
        configMap:
          name: swagger-ui-files
    - op: add
      path: /spec/template/spec/containers/0/volumeMounts
      value:
      - name: site
        mountPath: /usr/share/nginx/html
        readOnly: true
YAML

cat > k8s/apps/swagger-ui/kustomization.yaml <<YAML
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- overlays/dev
YAML

# 5. Dev environment composition
mkdir -p k8s/environments/dev
cat > k8s/environments/dev/kustomization.yaml <<YAML
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- ../../base
- ../../apps/auth-service
- ../../apps/booking-service
- ../../apps/gateway-service
- ../../apps/mail-service
- ../../apps/payment-service
- ../../apps/pricing-service
- ../../apps/user-service
- ../../apps/vehicle-service
- ../../apps/swagger-ui
YAML

echo "✅ k8s/ structure initialized with minimal configs!"
echo "➡️ Next: create Kind cluster"
EOF

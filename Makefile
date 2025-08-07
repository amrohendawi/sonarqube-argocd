# Makefile for SonarQube ArgoCD Deployment
# Provides easy commands for managing the deployment

.PHONY: help deploy deploy-dev deploy-prod status logs clean test lint check-deps port-forward

# Default target
help: ## Show this help message
	@echo "SonarQube ArgoCD Deployment Commands"
	@echo "=================================="
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# Variables
NAMESPACE ?= sonarqube
ARGOCD_NAMESPACE ?= argocd
APPLICATION_NAME ?= sonarqube
KUBECONFIG ?= ~/.kube/config

# Deployment commands
deploy: ## Deploy SonarQube with default values
	@echo "🚀 Deploying SonarQube with default configuration..."
	kubectl apply -f manifests/namespace.yaml
	kubectl apply -f argocd/sonarqube-application.yaml
	@echo "✅ Deployment initiated. Use 'make status' to check progress."

deploy-dev: ## Deploy SonarQube with development configuration
	@echo "🚀 Deploying SonarQube for development..."
	kubectl apply -f manifests/namespace.yaml
	# Create a temporary application manifest for development
	@sed 's/values.yaml/values-development.yaml/' argocd/sonarqube-application.yaml | kubectl apply -f -
	@echo "✅ Development deployment initiated."

deploy-prod: ## Deploy SonarQube with production configuration  
	@echo "🚀 Deploying SonarQube for production..."
	kubectl apply -f manifests/namespace.yaml
	# Create a temporary application manifest for production
	@sed 's/values.yaml/values-production.yaml/' argocd/sonarqube-application.yaml | kubectl apply -f -
	@echo "✅ Production deployment initiated."

# Status and monitoring commands
status: ## Show deployment status
	@echo "📊 SonarQube Deployment Status"
	@echo "============================="
	@echo "ArgoCD Application:"
	@kubectl get application $(APPLICATION_NAME) -n $(ARGOCD_NAMESPACE) -o wide 2>/dev/null || echo "❌ ArgoCD application not found"
	@echo ""
	@echo "Pods:"
	@kubectl get pods -n $(NAMESPACE) -o wide
	@echo ""
	@echo "Services:"
	@kubectl get svc -n $(NAMESPACE)
	@echo ""
	@echo "Persistent Volumes:"
	@kubectl get pvc -n $(NAMESPACE)

logs: ## Show SonarQube logs
	kubectl logs -f deployment/sonarqube-sonarqube -n $(NAMESPACE)

logs-postgres: ## Show PostgreSQL logs
	kubectl logs -f statefulset/sonarqube-postgresql -n $(NAMESPACE)

events: ## Show namespace events
	kubectl get events -n $(NAMESPACE) --sort-by='.lastTimestamp'

# Access commands
port-forward: ## Port forward SonarQube to localhost:9000
	@echo "🌐 Port forwarding SonarQube to http://localhost:9000"
	@echo "Press Ctrl+C to stop"
	kubectl port-forward svc/sonarqube-sonarqube 9000:9000 -n $(NAMESPACE)

port-forward-db: ## Port forward PostgreSQL to localhost:5432
	@echo "🗄️ Port forwarding PostgreSQL to localhost:5432"
	@echo "Press Ctrl+C to stop"
	kubectl port-forward svc/sonarqube-postgresql 5432:5432 -n $(NAMESPACE)

# Management commands
restart: ## Restart SonarQube deployment
	kubectl rollout restart deployment/sonarqube-sonarqube -n $(NAMESPACE)

scale-up: ## Scale SonarQube to 1 replica (CE max)
	kubectl scale deployment sonarqube-sonarqube --replicas=1 -n $(NAMESPACE)

scale-down: ## Scale SonarQube to 0 replicas
	kubectl scale deployment sonarqube-sonarqube --replicas=0 -n $(NAMESPACE)

# Sync and troubleshooting
sync: ## Force ArgoCD sync
	@if command -v argocd >/dev/null 2>&1; then \
		argocd app sync $(APPLICATION_NAME); \
	else \
		echo "⚠️ ArgoCD CLI not found. Manual sync required through ArgoCD UI"; \
		kubectl patch application $(APPLICATION_NAME) -n $(ARGOCD_NAMESPACE) --type merge -p '{"operation":{"sync":{"revision":"HEAD"}}}' || true; \
	fi

refresh: ## Force ArgoCD refresh
	@if command -v argocd >/dev/null 2>&1; then \
		argocd app get $(APPLICATION_NAME) --refresh; \
	else \
		echo "⚠️ ArgoCD CLI not found. Manual refresh required through ArgoCD UI"; \
	fi

# Testing commands
test: ## Run basic connectivity tests
	@echo "🧪 Running basic tests..."
	@echo "Testing namespace existence..."
	@kubectl get namespace $(NAMESPACE) >/dev/null && echo "✅ Namespace exists" || echo "❌ Namespace missing"
	@echo "Testing ArgoCD application..."
	@kubectl get application $(APPLICATION_NAME) -n $(ARGOCD_NAMESPACE) >/dev/null && echo "✅ ArgoCD application exists" || echo "❌ ArgoCD application missing"
	@echo "Testing SonarQube deployment..."
	@kubectl get deployment sonarqube-sonarqube -n $(NAMESPACE) >/dev/null && echo "✅ SonarQube deployment exists" || echo "❌ SonarQube deployment missing"

health-check: ## Check if SonarQube is responding
	@echo "🏥 Performing health check..."
	@kubectl run curl-test --image=curlimages/curl --rm -it --restart=Never -- \
		curl -f http://sonarqube-sonarqube.$(NAMESPACE).svc.cluster.local:9000/api/system/health || \
		echo "❌ Health check failed"

# Cleanup commands
clean: ## Remove SonarQube deployment
	@echo "🗑️ Cleaning up SonarQube deployment..."
	@read -p "Are you sure you want to delete the SonarQube deployment? [y/N] " -n 1 -r; \
	echo ""; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		kubectl delete application $(APPLICATION_NAME) -n $(ARGOCD_NAMESPACE) --ignore-not-found=true; \
		kubectl delete namespace $(NAMESPACE) --ignore-not-found=true; \
		echo "✅ Cleanup completed"; \
	else \
		echo "❌ Cleanup cancelled"; \
	fi

clean-force: ## Force remove SonarQube deployment without confirmation
	kubectl delete application $(APPLICATION_NAME) -n $(ARGOCD_NAMESPACE) --ignore-not-found=true
	kubectl delete namespace $(NAMESPACE) --ignore-not-found=true
	@echo "✅ Force cleanup completed"

# Utility commands
check-deps: ## Check if required dependencies are installed
	@echo "🔍 Checking dependencies..."
	@command -v kubectl >/dev/null 2>&1 && echo "✅ kubectl installed" || echo "❌ kubectl missing"
	@command -v helm >/dev/null 2>&1 && echo "✅ helm installed" || echo "❌ helm missing"
	@command -v argocd >/dev/null 2>&1 && echo "✅ argocd CLI installed" || echo "⚠️ argocd CLI missing (optional)"
	@kubectl get namespace $(ARGOCD_NAMESPACE) >/dev/null 2>&1 && echo "✅ ArgoCD namespace exists" || echo "❌ ArgoCD namespace missing"

lint: ## Lint Kubernetes manifests
	@echo "🔍 Linting Kubernetes manifests..."
	@if command -v kubeval >/dev/null 2>&1; then \
		kubeval manifests/*.yaml argocd/*.yaml; \
	elif command -v kubectl >/dev/null 2>&1; then \
		kubectl apply --dry-run=client -f manifests/ -f argocd/; \
		echo "✅ Dry-run validation passed"; \
	else \
		echo "⚠️ No linting tools found. Install kubeval or ensure kubectl is available"; \
	fi

# Information commands
info: ## Show deployment information and access details
	@echo "ℹ️ SonarQube Deployment Information"
	@echo "================================="
	@echo "Namespace: $(NAMESPACE)"
	@echo "ArgoCD Namespace: $(ARGOCD_NAMESPACE)"
	@echo "Application Name: $(APPLICATION_NAME)"
	@echo ""
	@echo "🌐 Access Methods:"
	@echo "1. Port Forward: make port-forward"
	@echo "2. NodePort (dev): kubectl get svc -n $(NAMESPACE)"
	@echo "3. Ingress (prod): Check ingress configuration"
	@echo ""
	@echo "🔑 Default Credentials:"
	@echo "Username: admin"
	@echo "Password: admin123 (or configured password)"

backup: ## Create a backup of PostgreSQL data
	@echo "💾 Creating PostgreSQL backup..."
	@kubectl exec -it statefulset/sonarqube-postgresql -n $(NAMESPACE) -- \
		pg_dump -U sonarUser -h localhost -d sonarDB > sonarqube-backup-$$(date +%Y%m%d-%H%M%S).sql
	@echo "✅ Backup completed"

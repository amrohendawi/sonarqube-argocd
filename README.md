# SonarQube Community Edition on ArgoCD

This repository contains the configuration files to deploy SonarQube Community Edition on a Kubernetes cluster using ArgoCD and GitOps principles.

## 📋 Prerequisites

- Kubernetes cluster (v1.20+)
- ArgoCD installed and configured
- Helm 3.x (for local testing)
- kubectl configured to access your cluster
- At least 4GB RAM and 2 CPU cores available in your cluster

## 🏗️ Architecture

This deployment includes:
- **SonarQube Community Edition** (v10.4.1) - Main application
- **PostgreSQL** (v12.12.10) - Database backend
- **Persistent Volumes** - For data persistence
- **ArgoCD Application** - GitOps management

## 📁 Repository Structure

```
sonarqube-argocd/
├── sonarqube/
│   ├── Chart.yaml          # Helm chart metadata
│   └── values.yaml         # SonarQube configuration
├── argocd/
│   └── sonarqube-application.yaml  # ArgoCD Application manifest
├── manifests/
│   ├── namespace.yaml      # Kubernetes namespace
│   ├── secrets-template.yaml    # Secrets template
│   └── ingress.yaml        # Optional ingress configuration
└── README.md              # This file
```

## 🚀 Quick Start

### Step 1: Fork and Clone

1. Fork this repository to your GitHub account
2. Clone your fork:
   ```bash
   git clone https://github.com/YOUR_USERNAME/sonarqube-argocd.git
   cd sonarqube-argocd
   ```

### Step 2: Update Configuration

1. **Update the ArgoCD Application manifest:**
   Edit `argocd/sonarqube-application.yaml` and replace:
   ```yaml
   source:
     repoURL: 'https://github.com/YOUR_USERNAME/sonarqube-argocd.git'
   ```

2. **Update domain (if using Ingress):**
   Edit `manifests/ingress.yaml` and replace:
   ```yaml
   - host: sonarqube.yourdomain.com
   ```

3. **Update passwords (for production):**
   Edit `sonarqube/values.yaml` and change default passwords:
   ```yaml
   sonarqube:
     account:
       adminPassword: "your-secure-password"
   postgresql:
     auth:
       postgresPassword: "your-postgres-password"
       password: "your-sonar-db-password"
   ```

### Step 3: Deploy

1. **Create the namespace:**
   ```bash
   kubectl apply -f manifests/namespace.yaml
   ```

2. **Deploy via ArgoCD:**
   ```bash
   kubectl apply -f argocd/sonarqube-application.yaml
   ```

### Step 4: Access SonarQube

1. **Port Forward (for testing):**
   ```bash
   kubectl port-forward svc/sonarqube-sonarqube 9000:9000 -n sonarqube
   ```
   Access at: http://localhost:9000

2. **Default credentials:**
   - Username: `admin`
   - Password: `admin123` (or what you configured)

## 🔧 Configuration Options

### Resource Requirements

Current configuration:
- **SonarQube**: 2GB RAM, 1 CPU (limits: 4GB RAM, 2 CPU)
- **PostgreSQL**: 512MB RAM, 0.5 CPU (limits: 1GB RAM, 1 CPU)
- **Storage**: 20GB each for SonarQube and PostgreSQL

### Scaling

To scale SonarQube (Community Edition supports 1 replica only):
```yaml
sonarqube:
  replicaCount: 1  # CE only supports 1 replica
```

### Plugins

Add Community plugins by updating `values.yaml`:
```yaml
sonarqube:
  plugins:
    install:
      - "https://github.com/mc1arke/sonarqube-community-branch-plugin/releases/download/1.14.0/sonarqube-community-branch-plugin-1.14.0.jar"
```

## 🛡️ Security Considerations

### Production Deployment

1. **Use Kubernetes Secrets:**
   ```bash
   # Create secrets instead of plain text passwords
   kubectl create secret generic sonarqube-admin-secret \
     --from-literal=admin-password=your-secure-password \
     -n sonarqube
   ```

2. **Enable TLS:**
   - Configure ingress with TLS certificates
   - Use cert-manager for automatic certificate management

3. **Network Policies:**
   Enable network policies to restrict traffic:
   ```yaml
   networkPolicy:
     enabled: true
   ```

4. **Resource Limits:**
   Ensure proper resource limits are set for production workloads.

## 🔍 Monitoring and Maintenance

### Health Checks

Monitor the deployment:
```bash
# Check ArgoCD application status
kubectl get application sonarqube -n argocd

# Check pods
kubectl get pods -n sonarqube

# Check services
kubectl get svc -n sonarqube

# View logs
kubectl logs -f deployment/sonarqube-sonarqube -n sonarqube
```

### Backup

Regular backup of PostgreSQL data is recommended:
```bash
kubectl exec -it postgresql-0 -n sonarqube -- pg_dump -U sonarUser sonarDB > sonarqube-backup.sql
```

## 🆙 Upgrades

To upgrade SonarQube:
1. Update the version in `sonarqube/Chart.yaml`
2. Commit changes to Git
3. ArgoCD will automatically sync the changes

## 🐛 Troubleshooting

### Common Issues

1. **Pods stuck in Pending:**
   ```bash
   kubectl describe pod -n sonarqube
   # Check for resource constraints or PV issues
   ```

2. **Database connection issues:**
   ```bash
   kubectl logs -f deployment/sonarqube-sonarqube -n sonarqube
   # Check PostgreSQL connectivity
   ```

3. **Memory issues:**
   ```bash
   # Increase memory limits in values.yaml
   sonarqube:
     resources:
       limits:
         memory: 6Gi
   ```

### Useful Commands

```bash
# Force ArgoCD sync
argocd app sync sonarqube

# Check ArgoCD application details
argocd app get sonarqube

# Restart SonarQube deployment
kubectl rollout restart deployment/sonarqube-sonarqube -n sonarqube
```

## 📚 References

- [SonarQube Official Helm Chart](https://github.com/SonarSource/helm-chart-sonarqube)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [SonarQube Documentation](https://docs.sonarqube.org/)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test the deployment
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

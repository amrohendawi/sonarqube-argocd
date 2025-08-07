# SonarQube Community Edition on ArgoCD

This repository contains the configuration files to deploy SonarQube Community Edition on a Kubernetes cluster using ArgoCD and GitOps principles. This is a fully functional GitOps deployment with comprehensive troubleshooting documentation based on real-world deployment experience.

## 📋 Prerequisites

- Kubernetes cluster (v1.20+)
- ArgoCD installed and configured
- Helm 3.x (for local testing)
- kubectl configured to access your cluster
- At least 4GB RAM and 2 CPU cores available in your cluster
- Git repository access for GitOps workflow

## 🏗️ Architecture

This deployment includes:
- **SonarQube Community Edition** (v10.4.1) - Main application for code quality analysis
- **PostgreSQL** (v12.12.10) - Database backend with persistent storage
- **Persistent Volumes** - For data persistence across pod restarts
- **ArgoCD Application** - GitOps management with automated sync
- **Kubernetes Secrets** - For secure credential management
- **Security Context** - Non-privileged containers for enhanced security

### Deployment Flow
```
Git Repository → ArgoCD → Kubernetes Cluster
     ↓              ↓            ↓
   values.yaml → Application → SonarQube + PostgreSQL
```

## 📁 Repository Structure

```
sonarqube-argocd/
├── sonarqube/
│   ├── Chart.yaml          # Helm chart metadata and dependencies
│   ├── values.yaml         # Main SonarQube configuration
│   ├── values-production.yaml   # Production-specific settings
│   └── values-development.yaml  # Development-specific settings
├── argocd/
│   └── sonarqube-application.yaml  # ArgoCD Application manifest
├── manifests/
│   ├── namespace.yaml      # Kubernetes namespace definition
│   ├── secrets-template.yaml    # Template for Kubernetes secrets
│   └── ingress.yaml        # Optional ingress configuration
├── Makefile               # Automation commands for deployment
├── deploy.sh             # Deployment automation script
└── README.md            # Comprehensive documentation (this file)
```

### Key Configuration Files

- **`sonarqube/values.yaml`**: Main configuration with security contexts, resource limits, database connections, and authentication settings
- **`argocd/sonarqube-application.yaml`**: ArgoCD application definition with sync policies and Git repository configuration
- **`sonarqube/Chart.yaml`**: Helm chart dependencies (SonarQube official chart + Bitnami PostgreSQL)

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

3. **Create admin credentials secret:**
   ```bash
   # Create the initial admin secret
   kubectl create secret generic sonarqube-admin-secret \
     --from-literal=admin-password=admin123 \
     --from-literal=current-admin-password=HEAD \
     -n sonarqube
   ```
   
   **Note**: The `current-admin-password` should be set to the existing password in SonarQube. If this is a fresh installation, it might be "admin" or could be affected by ArgoCD parameter substitution (see troubleshooting section).

### Step 3: Deploy

1. **Create the namespace:**
   ```bash
   kubectl apply -f manifests/namespace.yaml
   ```

2. **Deploy via ArgoCD:**
   ```bash
   kubectl apply -f argocd/sonarqube-application.yaml
   ```

3. **Monitor deployment:**
   ```bash
   # Check ArgoCD application status
   kubectl get application sonarqube -n argocd
   
   # Check pods
   kubectl get pods -n sonarqube
   ```

### Step 4: Access SonarQube

1. **Port Forward (for testing):**
   ```bash
   kubectl port-forward svc/sonarqube-sonarqube 9000:9000 -n sonarqube
   ```
   Access at: http://localhost:9000

2. **Initial login:**
   - Username: `admin`
   - Password: Check the secret or use default based on deployment method

## 🔧 Configuration Details

### Resource Requirements

Current configuration (production-ready):
- **SonarQube**: 
  - Requests: 1 CPU, 2GB RAM
  - Limits: 2 CPU, 4GB RAM
  - JVM: -Xmx3G -Xms1G
- **PostgreSQL**: 
  - Requests: 0.5 CPU, 512MB RAM
  - Limits: 1 CPU, 1GB RAM
- **Storage**: 20GB each for SonarQube and PostgreSQL

### Security Configuration

This deployment implements several security best practices:

1. **Non-privileged containers**: All containers run as non-root user (UID 1000)
2. **Security contexts**: Proper fsGroup and runAs settings
3. **Disabled privileged init containers**: Removes need for privileged access
4. **Secret-based authentication**: Uses Kubernetes secrets for password management
5. **Network policies**: Optional network isolation (disabled by default)

```yaml
securityContext:
  fsGroup: 1000
  runAsUser: 1000
  runAsGroup: 1000
  runAsNonRoot: true

initSysctl:
  enabled: false  # Disabled for security
```

### Database Configuration

PostgreSQL is configured with:
- **Persistent storage**: 20GB volume for data persistence
- **Custom naming**: Uses `sonarqube-postgresql` to avoid conflicts
- **Authentication**: Separate credentials for postgres admin and SonarQube user
- **Connection**: JDBC URL configured for SonarQube integration

### Authentication Management

The deployment uses Kubernetes secrets for credential management:

```yaml
account:
  adminPasswordSecretName: "sonarqube-admin-secret"
  adminPasswordSecretKey: "admin-password"
  currentAdminPasswordSecretName: "sonarqube-admin-secret"
  currentAdminPasswordSecretKey: "current-admin-password"
```

**Important**: The `currentAdminPassword` field is crucial for password updates in existing installations.

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

Monitor the deployment with these commands:
```bash
# Check ArgoCD application status
kubectl get application sonarqube -n argocd

# Detailed ArgoCD application info
kubectl describe application sonarqube -n argocd

# Check all pods in the namespace
kubectl get pods -n sonarqube

# Check services and endpoints
kubectl get svc,ep -n sonarqube

# View SonarQube logs
kubectl logs -f deployment/sonarqube-sonarqube -n sonarqube

# View PostgreSQL logs
kubectl logs -f statefulset/sonarqube-postgresql -n sonarqube

# Check persistent volumes
kubectl get pv,pvc -n sonarqube
```

### ArgoCD Management

```bash
# Force sync from Git repository
kubectl patch application sonarqube -n argocd --type merge -p='{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"now"}}}'

# Check sync status
kubectl get application sonarqube -n argocd -o jsonpath='{.status.sync.status}'

# View detailed application status
kubectl get application sonarqube -n argocd -o yaml
```

### Database Operations

```bash
# Connect to PostgreSQL
kubectl exec -it statefulset/sonarqube-postgresql -n sonarqube -- psql -U sonarUser -d sonarDB

# Backup database
kubectl exec -it statefulset/sonarqube-postgresql -n sonarqube -- pg_dump -U sonarUser sonarDB > sonarqube-backup.sql

# Check database connection from SonarQube
kubectl exec -it deployment/sonarqube-sonarqube -n sonarqube -- nc -zv sonarqube-postgresql 5432
```

## 🆙 Upgrade Strategy

### GitOps Upgrade Process

To upgrade SonarQube components:

1. **Update Chart version** in `sonarqube/Chart.yaml`:
   ```yaml
   dependencies:
   - name: sonarqube
     version: "10.5.0"  # New version
     repository: https://SonarSource.github.io/helm-chart-sonarqube
   ```

2. **Update application version** in `sonarqube/values.yaml`:
   ```yaml
   sonarqube:
     image:
       tag: "10.5.0-community"  # New version
   ```

3. **Test configuration changes**:
   ```bash
   helm template sonarqube ./sonarqube --values ./sonarqube/values.yaml
   ```

4. **Commit and push changes**:
   ```bash
   git add .
   git commit -m "Upgrade SonarQube to 10.5.0"
   git push origin main
   ```

5. **Monitor ArgoCD sync**:
   ```bash
   kubectl get application sonarqube -n argocd -w
   ```

### Pre-upgrade Checklist

- [ ] Backup database before major version upgrades
- [ ] Check SonarQube release notes for breaking changes
- [ ] Verify resource requirements for new version
- [ ] Test upgrade in development environment first
- [ ] Plan maintenance window for production upgrades

### Rollback Procedure

If upgrade fails:
1. **Revert Git commit**:
   ```bash
   git revert HEAD
   git push origin main
   ```

2. **Force ArgoCD sync**:
   ```bash
   kubectl patch application sonarqube -n argocd --type merge -p='{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"now"}}}'
   ```

3. **Restore database backup if needed**

## 🛡️ Production Deployment Guide

### Security Hardening

1. **Use strong passwords**:
   ```bash
   # Generate secure passwords
   ADMIN_PASSWORD=$(openssl rand -base64 32)
   POSTGRES_PASSWORD=$(openssl rand -base64 32)
   
   # Create secrets
   kubectl create secret generic sonarqube-admin-secret \
     --from-literal=admin-password=$ADMIN_PASSWORD \
     --from-literal=current-admin-password=admin \
     -n sonarqube
   
   kubectl create secret generic sonarqube-postgresql \
     --from-literal=postgres-password=$POSTGRES_PASSWORD \
     --from-literal=password=$POSTGRES_PASSWORD \
     -n sonarqube
   ```

2. **Enable TLS/Ingress**:
   ```yaml
   ingress:
     enabled: true
     annotations:
       kubernetes.io/ingress.class: nginx
       cert-manager.io/cluster-issuer: letsencrypt-prod
     hosts:
       - host: sonarqube.company.com
         paths:
           - path: /
             pathType: Prefix
     tls:
       - secretName: sonarqube-tls
         hosts:
           - sonarqube.company.com
   ```

3. **Enable network policies**:
   ```yaml
   networkPolicy:
     enabled: true
   ```

4. **Resource limits for production**:
   ```yaml
   sonarqube:
     resources:
       limits:
         cpu: 4000m
         memory: 8Gi
       requests:
         cpu: 2000m
         memory: 4Gi
   ```

### High Availability Considerations

**Note**: SonarQube Community Edition supports only 1 replica. For HA:
- Use external PostgreSQL cluster (RDS, Cloud SQL, etc.)
- Implement application-level backup and restore procedures
- Use persistent volumes with high IOPS for better performance

### Monitoring and Alerting

1. **Enable ServiceMonitor** (if using Prometheus):
   ```yaml
   serviceMonitor:
     enabled: true
   ```

2. **Key metrics to monitor**:
   - Pod resource usage (CPU, Memory)
   - Database connection count
   - Application response time
   - Persistent volume usage

### Environment-Specific Values

Use the provided environment-specific values files:
- `values-production.yaml` - Production settings
- `values-development.yaml` - Development settings

Deploy with specific environment:
```bash
# Update ArgoCD application to use production values
kubectl patch application sonarqube -n argocd --type merge -p='{
  "spec": {
    "source": {
      "helm": {
        "valueFiles": ["values-production.yaml"]
      }
    }
  }
}'
```

## 🐛 Troubleshooting Guide

This section documents common issues encountered during deployment and their solutions, based on real-world experience.

### Authentication Issues

**Problem**: Cannot login with admin credentials
**Symptoms**: Login fails with admin/admin or admin/admin123

**Root Cause**: ArgoCD parameter substitution can affect passwords in values.yaml. The parameter `$ARGOCD_APP_SOURCE_TARGET_REVISION` may be substituted into password fields, resulting in passwords like "HEAD" (the Git HEAD commit).

**Diagnosis**:
```bash
# Check the actual password in the secret
kubectl get secret sonarqube-admin-secret -n sonarqube -o jsonpath='{.data.admin-password}' | base64 -d
```

**Solutions**:
1. **Immediate access**: Use the actual password from the secret:
   ```bash
   PASSWORD=$(kubectl get secret sonarqube-admin-secret -n sonarqube -o jsonpath='{.data.admin-password}' | base64 -d)
   echo "Use admin/${PASSWORD}"
   ```

2. **Permanent fix**: Update values.yaml with proper current password:
   ```yaml
   account:
     currentAdminPassword: "HEAD"  # or actual current password
     adminPassword: "admin123"     # desired new password
   ```

### Resource and Security Issues

**Problem**: Pods stuck in Pending state
**Diagnosis**:
```bash
kubectl describe pod -n sonarqube
# Look for resource constraints or PV issues
```

**Solutions**:
- Increase node resources or adjust resource requests/limits
- Check PersistentVolume availability and storage class

**Problem**: Init containers failing with privileged access errors
**Symptoms**: `sysctlVmMaxMapCount` init container fails

**Solution**: Disable privileged init containers:
```yaml
initSysctl:
  enabled: false
initContainers:
  sysctlVmMaxMapCount:
    enabled: false
```

### Database Connection Issues

**Problem**: SonarQube cannot connect to PostgreSQL
**Diagnosis**:
```bash
kubectl logs -f deployment/sonarqube-sonarqube -n sonarqube | grep -i "database\|postgres\|connection"
```

**Common causes and solutions**:
1. **PostgreSQL not ready**: Wait for PostgreSQL pod to be running
2. **Connection string issues**: Verify JDBC URL in values.yaml
3. **Authentication issues**: Check PostgreSQL credentials match SonarQube config

### ArgoCD Sync Issues

**Problem**: ArgoCD shows "OutOfSync" status
**Diagnosis**:
```bash
kubectl describe application sonarqube -n argocd
```

**Solutions**:
1. **Force sync**:
   ```bash
   kubectl patch application sonarqube -n argocd --type merge -p='{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"now"}}}'
   ```

2. **Check Git repository access**: Verify ArgoCD can access the repository
3. **Validate YAML syntax**: Ensure all configuration files are valid

### Memory and Performance Issues

**Problem**: SonarQube OOM (Out of Memory) errors
**Symptoms**: Pods restarting frequently, OOM killed in logs

**Solutions**:
```yaml
sonarqube:
  resources:
    limits:
      memory: 6Gi  # Increase from default 4Gi
  jvmOpts: "-Xmx5G -Xms2G"  # Adjust JVM heap
```

### Plugin Issues

**Problem**: Community branch plugin causing startup failures
**Symptoms**: Plugin-related errors in logs

**Solution**: Remove problematic plugins or update JVM options:
```yaml
env: []
# Comment out or remove plugin-related environment variables
```

### Network and Ingress Issues

**Problem**: Cannot access SonarQube externally
**Diagnosis**:
```bash
# Test internal connectivity
kubectl exec -it deployment/sonarqube-sonarqube -n sonarqube -- curl -I localhost:9000

# Check service
kubectl get svc sonarqube-sonarqube -n sonarqube
```

**Solutions**:
1. **Port forwarding for testing**:
   ```bash
   kubectl port-forward svc/sonarqube-sonarqube 9000:9000 -n sonarqube
   ```

2. **Configure ingress properly** or use LoadBalancer service type

### Common Diagnostic Commands

```bash
# Get all resources in namespace
kubectl get all -n sonarqube

# Check events for errors
kubectl get events -n sonarqube --sort-by='.lastTimestamp'

# Check resource usage
kubectl top pods -n sonarqube

# Verify secrets
kubectl get secrets -n sonarqube
kubectl describe secret sonarqube-admin-secret -n sonarqube

# Check persistent volumes
kubectl get pv,pvc -n sonarqube
kubectl describe pvc -n sonarqube
```

## � GitOps Workflow

### Development Workflow

1. **Make configuration changes** locally in your development branch
2. **Test locally** using Helm:
   ```bash
   helm template sonarqube ./sonarqube --values ./sonarqube/values-development.yaml
   ```
3. **Commit and push** to feature branch
4. **Create pull request** for review
5. **Merge to main** branch after approval
6. **ArgoCD automatically syncs** changes to cluster

### Automated Sync Configuration

The ArgoCD application is configured with:
```yaml
syncPolicy:
  automated:
    prune: true      # Remove resources not in Git
    selfHeal: true   # Correct configuration drift
  syncOptions:
    - CreateNamespace=true
    - ApplyOutOfSyncOnly=true
```

### Configuration Management

- **Main configuration**: `sonarqube/values.yaml`
- **Environment overrides**: `values-production.yaml`, `values-development.yaml`
- **Secrets**: Managed via Kubernetes secrets (not in Git)
- **Git repository**: Single source of truth for all configurations

## 🧪 Testing and Validation

### Pre-deployment Testing

```bash
# Validate Helm chart
helm lint ./sonarqube

# Test template rendering
helm template sonarqube ./sonarqube --values ./sonarqube/values.yaml --debug

# Validate Kubernetes manifests
kubectl apply --dry-run=client -f argocd/sonarqube-application.yaml
```

### Post-deployment Validation

```bash
# Health check script
#!/bin/bash
echo "Checking SonarQube deployment health..."

# Check ArgoCD application
kubectl get application sonarqube -n argocd

# Check all pods are running
kubectl get pods -n sonarqube | grep -v Running && echo "Some pods not running!" || echo "All pods running ✓"

# Check services
kubectl get svc -n sonarqube

# Test internal connectivity
kubectl exec -it deployment/sonarqube-sonarqube -n sonarqube -- curl -f http://localhost:9000/api/system/status

echo "Health check complete!"
```

### Load Testing

For production validation:
```bash
# Port forward for testing
kubectl port-forward svc/sonarqube-sonarqube 9000:9000 -n sonarqube

# Use Apache Bench or similar tools
ab -n 100 -c 10 http://localhost:9000/
```

## � AI Agent Guidelines

### For Future AI Assistants

When working with this repository, follow these guidelines:

1. **Always check the current state** before making changes:
   ```bash
   kubectl get application sonarqube -n argocd
   kubectl get pods -n sonarqube
   ```

2. **Understand the authentication model**: This deployment uses Kubernetes secrets. Always check current passwords before attempting login.

3. **Use the troubleshooting guide**: Many common issues are documented with solutions.

4. **Follow GitOps principles**: Make changes through Git, not directly in Kubernetes.

5. **Test changes locally** using Helm before committing.

### Key Files for AI Agents to Understand

- `sonarqube/values.yaml` - Main configuration, contains all critical settings
- `argocd/sonarqube-application.yaml` - ArgoCD application definition
- `sonarqube/Chart.yaml` - Helm dependencies and versions
- This README.md - Comprehensive documentation and troubleshooting

### Common AI Agent Tasks

1. **Debugging login issues**: Check secrets, decode base64 passwords, identify ArgoCD parameter substitution issues
2. **Resource optimization**: Adjust CPU/memory based on usage patterns
3. **Security hardening**: Review and implement security best practices
4. **Upgrade planning**: Version compatibility checks and upgrade procedures

## 📚 References and Resources

### Official Documentation
- [SonarQube Official Helm Chart](https://github.com/SonarSource/helm-chart-sonarqube)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [SonarQube Documentation](https://docs.sonarqube.org/)
- [Bitnami PostgreSQL Helm Chart](https://github.com/bitnami/charts/tree/main/bitnami/postgresql)

### Kubernetes Resources
- [Kubernetes Security Contexts](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/)
- [Kubernetes Secrets Management](https://kubernetes.io/docs/concepts/configuration/secret/)
- [Persistent Volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)

### GitOps and CI/CD
- [ArgoCD Best Practices](https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/)
- [GitOps Principles](https://opengitops.dev/)
- [Helm Best Practices](https://helm.sh/docs/chart_best_practices/)

## 🤝 Contributing

### Development Guidelines

1. **Fork and clone** the repository
2. **Create a feature branch** from main:
   ```bash
   git checkout -b feature/your-improvement
   ```
3. **Make changes** following the established patterns
4. **Test thoroughly** in development environment
5. **Update documentation** if needed
6. **Submit a pull request** with detailed description

### Code Review Checklist

- [ ] Changes tested in development environment
- [ ] Documentation updated
- [ ] Security considerations reviewed
- [ ] Resource requirements validated
- [ ] GitOps workflow maintained

### Reporting Issues

When reporting issues, include:
- Kubernetes version and cluster information
- ArgoCD version
- Complete error messages and logs
- Steps to reproduce
- Expected vs actual behavior

## 🏷️ Version History

### v1.0.0 - Initial Release
- Complete SonarQube Community Edition deployment
- ArgoCD GitOps integration
- PostgreSQL database with persistent storage
- Security-hardened configuration
- Comprehensive documentation and troubleshooting guide

### Recent Updates
- Fixed ArgoCD parameter substitution authentication issues
- Added environment-specific configuration files
- Enhanced security contexts for non-privileged deployment
- Comprehensive troubleshooting documentation based on real-world issues

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 💡 Support and Community

### Getting Help

1. **Check the troubleshooting guide** in this README first
2. **Review GitHub Issues** for similar problems
3. **Create a new issue** with detailed information
4. **Join the community** discussions for questions and improvements

### Acknowledgments

This repository was developed through hands-on deployment experience, addressing real-world challenges in deploying SonarQube with ArgoCD. Special thanks to the open-source community for the excellent tools and documentation that made this possible.

---

**Repository**: https://github.com/amrohendawi/sonarqube-argocd  
**Maintainer**: [@amrohendawi](https://github.com/amrohendawi)  
**Last Updated**: January 2025

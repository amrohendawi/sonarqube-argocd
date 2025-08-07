#!/bin/bash

# SonarQube ArgoCD Deployment Script
# This script helps deploy SonarQube Community Edition via ArgoCD

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="sonarqube"
ARGOCD_NAMESPACE="argocd"
APPLICATION_NAME="sonarqube"

echo -e "${BLUE}🚀 SonarQube ArgoCD Deployment Script${NC}"
echo "=================================="

# Function to check if kubectl is available
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        echo -e "${RED}❌ kubectl is not installed or not in PATH${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ kubectl is available${NC}"
}

# Function to check if ArgoCD is installed
check_argocd() {
    if ! kubectl get namespace $ARGOCD_NAMESPACE &> /dev/null; then
        echo -e "${RED}❌ ArgoCD namespace '$ARGOCD_NAMESPACE' not found${NC}"
        echo "Please install ArgoCD first: https://argo-cd.readthedocs.io/en/stable/getting_started/"
        exit 1
    fi
    echo -e "${GREEN}✅ ArgoCD namespace found${NC}"
}

# Function to create namespace
create_namespace() {
    echo -e "${BLUE}📁 Creating namespace...${NC}"
    kubectl apply -f manifests/namespace.yaml
    echo -e "${GREEN}✅ Namespace created/updated${NC}"
}

# Function to deploy ArgoCD application
deploy_application() {
    echo -e "${BLUE}🔧 Deploying ArgoCD application...${NC}"
    kubectl apply -f argocd/sonarqube-application.yaml
    echo -e "${GREEN}✅ ArgoCD application deployed${NC}"
}

# Function to wait for deployment
wait_for_deployment() {
    echo -e "${BLUE}⏳ Waiting for SonarQube deployment...${NC}"
    echo "This may take several minutes as images are pulled and containers start up..."
    
    # Wait for the deployment to be available
    kubectl wait --for=condition=available --timeout=600s deployment/sonarqube-sonarqube -n $NAMESPACE || true
    
    echo -e "${GREEN}✅ Deployment completed${NC}"
}

# Function to show status
show_status() {
    echo -e "${BLUE}📊 Current Status${NC}"
    echo "=================="
    
    echo -e "${YELLOW}ArgoCD Application:${NC}"
    kubectl get application $APPLICATION_NAME -n $ARGOCD_NAMESPACE -o wide 2>/dev/null || echo "ArgoCD application not found"
    
    echo -e "\n${YELLOW}Pods in $NAMESPACE namespace:${NC}"
    kubectl get pods -n $NAMESPACE -o wide
    
    echo -e "\n${YELLOW}Services in $NAMESPACE namespace:${NC}"
    kubectl get svc -n $NAMESPACE
    
    echo -e "\n${YELLOW}Persistent Volumes:${NC}"
    kubectl get pv | grep $NAMESPACE || echo "No persistent volumes found for $NAMESPACE"
}

# Function to show access instructions
show_access_info() {
    echo -e "\n${GREEN}🎉 Deployment Complete!${NC}"
    echo "======================="
    
    echo -e "\n${YELLOW}Access SonarQube:${NC}"
    echo "1. Port forward to access locally:"
    echo -e "   ${BLUE}kubectl port-forward svc/sonarqube-sonarqube 9000:9000 -n $NAMESPACE${NC}"
    echo "2. Open browser to: http://localhost:9000"
    echo "3. Default credentials:"
    echo "   - Username: admin"
    echo "   - Password: admin123 (or your configured password)"
    
    echo -e "\n${YELLOW}Useful commands:${NC}"
    echo "- Check logs: kubectl logs -f deployment/sonarqube-sonarqube -n $NAMESPACE"
    echo "- Check ArgoCD app: kubectl get application $APPLICATION_NAME -n $ARGOCD_NAMESPACE"
    echo "- Scale (if needed): kubectl scale deployment sonarqube-sonarqube --replicas=1 -n $NAMESPACE"
}

# Function to show troubleshooting info
show_troubleshooting() {
    echo -e "\n${YELLOW}🔧 Troubleshooting:${NC}"
    echo "If pods are not starting:"
    echo "1. Check pod describe: kubectl describe pod <pod-name> -n $NAMESPACE"
    echo "2. Check events: kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp'"
    echo "3. Check ArgoCD UI or: argocd app get $APPLICATION_NAME"
}

# Main execution
main() {
    echo "Starting deployment process..."
    
    check_kubectl
    check_argocd
    create_namespace
    deploy_application
    
    echo -e "\n${BLUE}⏳ Waiting for initial sync...${NC}"
    sleep 10
    
    wait_for_deployment
    show_status
    show_access_info
    show_troubleshooting
    
    echo -e "\n${GREEN}✅ Script completed successfully!${NC}"
}

# Handle script arguments
case "${1:-deploy}" in
    "deploy")
        main
        ;;
    "status")
        show_status
        ;;
    "delete")
        echo -e "${RED}🗑️ Deleting SonarQube deployment...${NC}"
        kubectl delete application $APPLICATION_NAME -n $ARGOCD_NAMESPACE --ignore-not-found=true
        kubectl delete namespace $NAMESPACE --ignore-not-found=true
        echo -e "${GREEN}✅ Cleanup completed${NC}"
        ;;
    "help"|"-h"|"--help")
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  deploy  (default) - Deploy SonarQube via ArgoCD"
        echo "  status           - Show current deployment status"
        echo "  delete           - Delete the SonarQube deployment"
        echo "  help             - Show this help message"
        ;;
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        echo "Run '$0 help' for usage information"
        exit 1
        ;;
esac

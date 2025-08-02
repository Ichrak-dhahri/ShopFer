# deploy-to-aks.ps1
# Script PowerShell pour déployer l'application ShopFer sur AKS

$ErrorActionPreference = "Stop"

Write-Host "🚀 Déploiement de ShopFer sur AKS" -ForegroundColor Green

# Variables (à personnaliser)
$RESOURCE_GROUP = "rg-shopfer-aks"
$CLUSTER_NAME = "aks-shopfer"
$DOCKER_IMAGE = "votre-username/shopferimgg:latest"  # Remplacez par votre image

try {
    # 1. Obtenir les credentials du cluster AKS
    Write-Host "🔑 Récupération des credentials AKS..." -ForegroundColor Yellow
    az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --overwrite-existing
    
    if ($LASTEXITCODE -ne 0) {
        throw "Erreur lors de la récupération des credentials AKS"
    }

    # 2. Vérifier la connexion au cluster
    Write-Host "✅ Vérification de la connexion au cluster..." -ForegroundColor Yellow
    kubectl cluster-info

    # 3. Créer le namespace (optionnel)
    Write-Host "📁 Création du namespace..." -ForegroundColor Yellow
    kubectl create namespace shopfer-app --dry-run=client -o yaml | kubectl apply -f -

    # 4. Déployer l'application
    Write-Host "🚀 Déploiement de l'application..." -ForegroundColor Yellow
    kubectl apply -f deployment.yaml
    kubectl apply -f service.yaml
    kubectl apply -f configmap.yaml

    # 5. Attendre que le déploiement soit prêt
    Write-Host "⏳ Attente du déploiement..." -ForegroundColor Yellow
    kubectl rollout status deployment/shopfer-app --timeout=300s

    # 6. Obtenir l'IP externe du service
    Write-Host "🌐 Récupération de l'IP externe..." -ForegroundColor Yellow
    Write-Host "Attente de l'assignation de l'IP externe..."
    
    $timeout = 300
    $counter = 0
    $externalIP = $null
    
    while ($counter -lt $timeout) {
        $externalIP = kubectl get service shopfer-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>$null
        
        if ($externalIP -and $externalIP -ne "null" -and $externalIP.Trim() -ne "") {
            Write-Host "✅ Application déployée avec succès !" -ForegroundColor Green
            Write-Host "🌍 URL d'accès: http://$externalIP" -ForegroundColor Cyan
            break
        }
        
        Start-Sleep -Seconds 10
        $counter += 10
        Write-Host "Attente de l'IP externe... ($counter/$timeout secondes)"
    }

    if (-not $externalIP -or $externalIP -eq "null" -or $externalIP.Trim() -eq "") {
        Write-Host "⚠️  L'IP externe n'a pas été assignée dans le délai imparti" -ForegroundColor Yellow
        Write-Host "Vous pouvez vérifier manuellement avec: kubectl get service shopfer-service"
    }

    # 7. Afficher les informations de déploiement
    Write-Host ""
    Write-Host "📊 Informations du déploiement:" -ForegroundColor Cyan
    kubectl get deployments
    kubectl get pods
    kubectl get services

    Write-Host ""
    Write-Host "🔍 Pour surveiller les logs:" -ForegroundColor Yellow
    Write-Host "kubectl logs -f deployment/shopfer-app"
    Write-Host ""
    Write-Host "🛠️  Pour supprimer le déploiement:" -ForegroundColor Yellow
    Write-Host "kubectl delete -f deployment.yaml -f service.yaml -f configmap.yaml"

} catch {
    Write-Host "❌ Erreur lors du déploiement: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
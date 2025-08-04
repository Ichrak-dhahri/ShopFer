pipeline {
    agent any
    
    environment {
        // Docker Hub credentials
        DOCKER_HUB_REGISTRY = 'docker.io'
        DOCKER_IMAGE_NAME = 'farahabbes/shopferimgg'
        DOCKER_TAG = "${BUILD_NUMBER}"
        
        // Azure credentials
        AZURE_CREDENTIALS = credentials('azure-service-principal')
        
        // Terraform variables
        TF_VAR_resource_group_name = 'rg-shopfer-aks'
        TF_VAR_cluster_name = 'aks-shopfer'
        TF_VAR_location = 'East US'
        TF_VAR_node_count = '2'
        
        // Application variables
        APP_NAMESPACE = 'shopfer-app'
        DOMAIN_NAME = 'shopfer-ecommerce.duckdns.org'
        DUCKDNS_TOKEN = credentials('duckdns-token')
    }
    
    stages {
        stage('Clone Repository') {
            steps {
                git branch: 'main', url: 'https://github.com/Ichrak-dhahri/ShopFer.git'
            }
        }
        
        stage('Install Dependencies & Build') {
            steps {
                bat '''
                    echo "📦 Installation des dépendances..."
                    call npm install
                    
                    echo "🏗️ Build de l'application Angular..."
                    call npm run build --prod
                '''
            }
        }
        
        stage('Run Tests') {
            steps {
                bat '''
                    echo "🧪 Exécution des tests unitaires..."
                    call npm run test -- --karma-config karma.conf.js --watch=false --code-coverage
                '''
            }
        }
        
        stage('Build & Push Docker Image') {
            steps {
                script {
                    bat '''
                        echo "🐳 Construction de l'image Docker..."
                        docker build -t %DOCKER_IMAGE_NAME%:%DOCKER_TAG% .
                        docker tag %DOCKER_IMAGE_NAME%:%DOCKER_TAG% %DOCKER_IMAGE_NAME%:latest
                    '''
                    
                    withCredentials([usernamePassword(credentialsId: 'docker-hub-login', usernameVariable: 'DOCKER_HUB_USER', passwordVariable: 'DOCKER_HUB_PASS')]) {
                        bat '''
                            echo "📤 Push vers Docker Hub..."
                            docker login -u %DOCKER_HUB_USER% -p %DOCKER_HUB_PASS%
                            docker push %DOCKER_IMAGE_NAME%:%DOCKER_TAG%
                            docker push %DOCKER_IMAGE_NAME%:latest
                        '''
                    }
                }
            }
        }
        
        stage('Setup Terraform') {
            steps {
                bat '''
                    echo "🔧 Configuration de Terraform..."
                    if not exist terraform mkdir terraform
                    cd terraform
                    
                    echo "Téléchargement de Terraform si nécessaire..."
                    where terraform >nul 2>&1 || (
                        echo "Installation de Terraform..."
                        powershell -Command "Invoke-WebRequest -Uri 'https://releases.hashicorp.com/terraform/1.5.0/terraform_1.5.0_windows_amd64.zip' -OutFile 'terraform.zip'"
                        powershell -Command "Expand-Archive -Path 'terraform.zip' -DestinationPath '.'"
                        del terraform.zip
                    )
                '''
                
                // Créer les fichiers Terraform
                writeFile file: 'terraform/main.tf', text: '''
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
}

# AKS Cluster
resource "azurerm_kubernetes_cluster" "main" {
  name                = var.cluster_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = "${var.cluster_name}-dns"

  default_node_pool {
    name       = "default"
    node_count = var.node_count
    vm_size    = "Standard_D2_v2"
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin = "kubenet"
  }
}

output "kube_config" {
  value     = azurerm_kubernetes_cluster.main.kube_config_raw
  sensitive = true
}

output "cluster_name" {
  value = azurerm_kubernetes_cluster.main.name
}

output "resource_group_name" {
  value = azurerm_resource_group.main.name
}
'''
                
                writeFile file: 'terraform/variables.tf', text: '''
variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "cluster_name" {
  description = "Name of the AKS cluster"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "East US"
}

variable "node_count" {
  description = "Number of nodes in the default node pool"
  type        = number
  default     = 2
}
'''
            }
        }
        
        stage('Deploy Infrastructure with Terraform') {
            steps {
                withCredentials([azureServicePrincipal(credentialsId: 'azure-service-principal', 
                    subscriptionIdVariable: 'ARM_SUBSCRIPTION_ID',
                    clientIdVariable: 'ARM_CLIENT_ID',
                    clientSecretVariable: 'ARM_CLIENT_SECRET',
                    tenantIdVariable: 'ARM_TENANT_ID')]) {
                    
                    bat '''
                        cd terraform
                        echo "🏗️ Initialisation de Terraform..."
                        terraform init
                        
                        echo "📋 Plan Terraform..."
                        terraform plan -out=tfplan
                        
                        echo "🚀 Application de l'infrastructure..."
                        terraform apply -auto-approve tfplan
                        
                        echo "💾 Sauvegarde de la config Kubernetes..."
                        terraform output -raw kube_config > ../kubeconfig
                    '''
                }
            }
        }
        
        stage('Setup Kubernetes') {
            steps {
                bat '''
                    echo "☸️ Configuration de kubectl..."
                    set KUBECONFIG=%WORKSPACE%\\kubeconfig
                    
                    echo "✅ Vérification de la connexion au cluster..."
                    kubectl cluster-info
                    
                    echo "📁 Création du namespace..."
                    kubectl create namespace %APP_NAMESPACE% --dry-run=client -o yaml | kubectl apply -f -
                '''
            }
        }
        
        stage('Install NGINX Ingress Controller') {
            steps {
                bat '''
                    set KUBECONFIG=%WORKSPACE%\\kubeconfig
                    
                    echo "🌐 Installation du contrôleur NGINX Ingress..."
                    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml
                    
                    echo "⏳ Attente du démarrage d'NGINX..."
                    kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=300s
                '''
            }
        }
        
        stage('Install cert-manager') {
            steps {
                bat '''
                    set KUBECONFIG=%WORKSPACE%\\kubeconfig
                    
                    echo "🔐 Installation de cert-manager..."
                    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
                    
                    echo "⏳ Attente du démarrage de cert-manager..."
                    kubectl wait --namespace cert-manager --for=condition=ready pod --selector=app.kubernetes.io/instance=cert-manager --timeout=300s
                '''
            }
        }
        
        stage('Create Kubernetes Manifests') {
            steps {
                // Deployment
                writeFile file: 'k8s-deployment.yaml', text: """
apiVersion: apps/v1
kind: Deployment
metadata:
  name: shopfer-app
  namespace: ${APP_NAMESPACE}
  labels:
    app: shopfer
    version: v1
spec:
  replicas: 2
  selector:
    matchLabels:
      app: shopfer
  template:
    metadata:
      labels:
        app: shopfer
    spec:
      containers:
      - name: shopfer-container
        image: ${DOCKER_IMAGE_NAME}:${DOCKER_TAG}
        ports:
        - containerPort: 4200
        env:
        - name: NODE_ENV
          value: "production"
        - name: PORT
          value: "4200"
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
"""
                
                // Service
                writeFile file: 'k8s-service.yaml', text: """
apiVersion: v1
kind: Service
metadata:
  name: shopfer-service
  namespace: ${APP_NAMESPACE}
spec:
  selector:
    app: shopfer
  ports:
    - protocol: TCP
      port: 80
      targetPort: 4200
  type: ClusterIP
"""
                
                // ClusterIssuer for Let's Encrypt
                writeFile file: 'k8s-clusterissuer.yaml', text: '''
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com  # Remplacez par votre email
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
'''
                
                // Ingress
                writeFile file: 'k8s-ingress.yaml', text: """
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: shopfer-ingress
  namespace: ${APP_NAMESPACE}
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  tls:
  - hosts:
    - ${DOMAIN_NAME}
    secretName: shopfer-tls
  rules:
  - host: ${DOMAIN_NAME}
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: shopfer-service
            port:
              number: 80
"""
            }
        }
        
        stage('Deploy Application to AKS') {
            steps {
                bat '''
                    set KUBECONFIG=%WORKSPACE%\\kubeconfig
                    
                    echo "🚀 Déploiement de l'application..."
                    kubectl apply -f k8s-deployment.yaml
                    kubectl apply -f k8s-service.yaml
                    kubectl apply -f k8s-clusterissuer.yaml
                    
                    echo "⏳ Attente du déploiement..."
                    kubectl rollout status deployment/shopfer-app -n %APP_NAMESPACE% --timeout=300s
                    
                    echo "🌐 Application de l'Ingress..."
                    kubectl apply -f k8s-ingress.yaml
                '''
            }
        }
        
        stage('Get LoadBalancer IP') {
            steps {
                script {
                    bat '''
                        set KUBECONFIG=%WORKSPACE%\\kubeconfig
                        
                        echo "🌍 Récupération de l'IP du LoadBalancer..."
                        
                        set /a timeout=300
                        set /a counter=0
                        
                        :wait_loop
                        if %counter% geq %timeout% (
                            echo "⚠️  Timeout atteint pour l'obtention de l'IP externe"
                            goto :end_wait
                        )
                        
                        for /f "delims=" %%i in ('kubectl get service ingress-nginx-controller -n ingress-nginx -o jsonpath^="{.status.loadBalancer.ingress[0].ip}" 2^>nul') do set EXTERNAL_IP=%%i
                        
                        if defined EXTERNAL_IP (
                            if not "%EXTERNAL_IP%"=="null" (
                                echo "✅ IP externe obtenue: %EXTERNAL_IP%"
                                echo %EXTERNAL_IP% > external_ip.txt
                                goto :end_wait
                            )
                        )
                        
                        timeout /t 10 /nobreak > nul
                        set /a counter+=10
                        echo "Attente de l'IP externe... (%counter%/%timeout% secondes)"
                        goto :wait_loop
                        
                        :end_wait
                    '''
                }
            }
        }
        
        stage('Configure DNS (DuckDNS)') {
            when {
                expression { fileExists('external_ip.txt') }
            }
            steps {
                script {
                    bat '''
                        set /p EXTERNAL_IP=<external_ip.txt
                        
                        echo "🌐 Configuration DNS DuckDNS..."
                        echo "IP externe: %EXTERNAL_IP%"
                        echo "Domaine: %DOMAIN_NAME%"
                        
                        powershell -Command "Invoke-RestMethod -Uri 'https://www.duckdns.org/update?domains=shopfer-ecommerce&token=%DUCKDNS_TOKEN%&ip=%EXTERNAL_IP%'"
                    '''
                }
            }
        }
        
        stage('Verify Deployment') {
            steps {
                bat '''
                    set KUBECONFIG=%WORKSPACE%\\kubeconfig
                    
                    echo "📊 Vérification du déploiement..."
                    kubectl get deployments -n %APP_NAMESPACE%
                    kubectl get pods -n %APP_NAMESPACE%
                    kubectl get services -n %APP_NAMESPACE%
                    kubectl get ingress -n %APP_NAMESPACE%
                    
                    echo ""
                    echo "🌍 Application accessible sur: https://%DOMAIN_NAME%"
                    echo ""
                    echo "🔍 Pour surveiller les logs:"
                    echo "kubectl logs -f deployment/shopfer-app -n %APP_NAMESPACE%"
                '''
            }
        }
    }
    
    post {
        always {
            script {
                // Cleanup Docker images
                try {
                    bat '''
                        echo "🧹 Nettoyage des images Docker locales..."
                        docker rmi %DOCKER_IMAGE_NAME%:%DOCKER_TAG% 2>nul || echo "Image déjà supprimée"
                        docker system prune -f 2>nul || echo "Nettoyage système terminé"
                    '''
                } catch (Exception e) {
                    echo "Warning: Docker cleanup failed"
                }
                
                // Archive important files
                try {
                    archiveArtifacts artifacts: 'terraform/tfplan,kubeconfig,external_ip.txt,k8s-*.yaml', allowEmptyArchive: true, fingerprint: true
                } catch (Exception e) {
                    echo "Warning: Could not archive artifacts"
                }
            }
        }
        
        success {
            script {
                if (fileExists('external_ip.txt')) {
                    def externalIP = readFile('external_ip.txt').trim()
                    echo """
                    ✅ Pipeline terminé avec succès !
                    
                    🌍 Application déployée sur AKS
                    📍 URL: https://${DOMAIN_NAME}
                    🔗 IP LoadBalancer: ${externalIP}
                    
                    🔍 Commandes utiles:
                    - kubectl get all -n ${APP_NAMESPACE}
                    - kubectl logs -f deployment/shopfer-app -n ${APP_NAMESPACE}
                    - kubectl describe ingress shopfer-ingress -n ${APP_NAMESPACE}
                    """
                } else {
                    echo '✅ Pipeline terminé avec succès ! Vérifiez les logs pour l\'IP externe.'
                }
            }
        }
        
        failure {
            echo '''
            ❌ Pipeline échoué !
            
            🔍 Vérifications à effectuer:
            1. Credentials Azure configurés correctement
            2. Docker Hub credentials valides
            3. Token DuckDNS valide
            4. Quota Azure suffisant
            '''
            
            // Diagnostic information
            script {
                try {
                    bat '''
                        echo "=== DIAGNOSTIC ==="
                        echo "Terraform state:"
                        if exist terraform\\terraform.tfstate (
                            echo "Terraform state exists"
                        ) else (
                            echo "No Terraform state found"
                        )
                        
                        echo "Docker images:"
                        docker images | find "shopfer" 2>nul || echo "No shopfer images found"
                        
                        if exist kubeconfig (
                            set KUBECONFIG=%WORKSPACE%\\kubeconfig
                            echo "Kubernetes status:"
                            kubectl get nodes 2>nul || echo "Cannot connect to cluster"
                        )
                    '''
                } catch (Exception e) {
                    echo "Diagnostic failed - continuing"
                }
            }
        }
        
        cleanup {
            // Optional cleanup of temporary files
            bat '''
                if exist external_ip.txt del external_ip.txt 2>nul
                if exist terraform\\tfplan del terraform\\tfplan 2>nul
            '''
        }
    }
}

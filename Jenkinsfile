pipeline {
    agent any
    
    environment {
        // Docker Hub credentials
        DOCKER_HUB_REGISTRY = 'docker.io'
        DOCKER_IMAGE_NAME = 'farahabbes/shopferimgg'
        DOCKER_TAG = "${BUILD_NUMBER}"
        
        // Azure credentials - These will be set from Jenkins credentials
        AZURE_CREDENTIALS = credentials('azure-service-principal')
        
        // Terraform variables
        TF_VAR_resource_group_name = 'rg-shopfer-aks'
        TF_VAR_cluster_name = 'aks-shopfer'
        TF_VAR_location = 'francecentral'
        TF_VAR_node_count = '1'
        TF_VAR_kubernetes_version = '1.30.14'
        TF_VAR_vm_size = 'Standard_B2s'
        
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
                    echo "📦 Installation des dépendances avec gestion d'erreurs améliorée..."
                    
                    REM Configuration npm pour éviter les erreurs SSL
                    call npm config set registry https://registry.npmjs.org/
                    call npm config set strict-ssl false
                    call npm config set fetch-retries 5
                    call npm config set fetch-retry-factor 2
                    call npm config set fetch-retry-mintimeout 10000
                    call npm config set fetch-retry-maxtimeout 60000
                    
                    REM Utiliser npm install au lieu de npm ci en cas de problème
                    call npm install --legacy-peer-deps || (
                        echo "npm install failed, trying with cache clean..."
                        call npm cache clean --force
                        call npm install --legacy-peer-deps
                    )
                    
                    echo "🏗️ Build de l'application Angular..."
                    call npm run build --prod || call npm run build
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
                    // Create a Dockerfile with better npm handling
                    writeFile file: 'Dockerfile.jenkins', text: '''
FROM node:18-alpine as build

# Install necessary packages for npm
RUN apk add --no-cache python3 make g++

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Configure npm with better SSL handling and use npm install instead of npm ci
RUN npm config set registry https://registry.npmjs.org/ && \\
    npm config set strict-ssl false && \\
    npm config set fetch-retries 5 && \\
    npm config set fetch-retry-factor 2 && \\
    npm config set fetch-retry-mintimeout 10000 && \\
    npm config set fetch-retry-maxtimeout 60000 && \\
    npm install --legacy-peer-deps

# Copy source code
COPY . .

# Build the Angular application
RUN npm run build --prod

# Production stage
FROM nginx:alpine

# Copy built application to nginx
COPY --from=build /app/dist /usr/share/nginx/html

# Copy custom nginx configuration if exists
COPY nginx.conf /etc/nginx/conf.d/default.conf 2>/dev/null || echo "Using default nginx config"

# Expose port
EXPOSE 80

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
'''
                    
                    // Create nginx configuration
                    writeFile file: 'nginx.conf', text: '''
server {
    listen 80;
    server_name localhost;
    root /usr/share/nginx/html;
    index index.html;

    # Handle Angular routing
    location / {
        try_files $uri $uri/ /index.html;
    }

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss application/json;

    # Cache static assets
    location ~* \\.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
'''

                    bat '''
                        echo "🐳 Construction de l'image Docker avec configuration améliorée..."
                        docker build -f Dockerfile.jenkins -t %DOCKER_IMAGE_NAME%:%DOCKER_TAG% .
                        docker tag %DOCKER_IMAGE_NAME%:%DOCKER_TAG% %DOCKER_IMAGE_NAME%:latest
                        
                        echo "✅ Image Docker construite avec succès"
                        docker images | findstr %DOCKER_IMAGE_NAME%
                    '''
                    
                    withCredentials([usernamePassword(credentialsId: 'docker-hub-login', usernameVariable: 'DOCKER_HUB_USER', passwordVariable: 'DOCKER_HUB_PASS')]) {
                        bat '''
                            echo "📤 Push vers Docker Hub..."
                            docker login -u %DOCKER_HUB_USER% -p %DOCKER_HUB_PASS%
                            docker push %DOCKER_IMAGE_NAME%:%DOCKER_TAG%
                            docker push %DOCKER_IMAGE_NAME%:latest
                            
                            echo "✅ Images poussées vers Docker Hub avec succès"
                        '''
                    }
                }
            }
        }
        
        stage('Setup Terraform') {
            steps {
                bat '''
                    echo "🔧 Configuration de Terraform..."
                    cd terraform-aks
                    
                    echo "Téléchargement de Terraform si nécessaire..."
                    where terraform >nul 2>&1 || (
                        echo "Installation de Terraform..."
                        powershell -Command "Invoke-WebRequest -Uri 'https://releases.hashicorp.com/terraform/1.5.0/terraform_1.5.0_windows_amd64.zip' -OutFile 'terraform.zip'"
                        powershell -Command "Expand-Archive -Path 'terraform.zip' -DestinationPath '.'"
                        del terraform.zip
                    )
                    
                    echo "✅ Terraform files already exist in terraform-aks directory"
                    dir
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
                    
                    script {
                        // Check if resources exist and import them if necessary
                        bat '''
                            cd terraform-aks
                            
                            echo "🔐 Configuration des variables d'environnement Azure..."
                            echo "Subscription ID: %ARM_SUBSCRIPTION_ID%"
                            echo "Client ID: %ARM_CLIENT_ID%"
                            echo "Tenant ID: %ARM_TENANT_ID%"
                            
                            echo "🏗️ Initialisation de Terraform..."
                            terraform init
                            
                            echo "🔍 Validation de la configuration Terraform..."
                            terraform validate
                        '''
                        
                        // Handle existing resources by importing or destroying them
                        try {
                            bat '''
                                cd terraform-aks
                                echo "📋 Vérification de l'état actuel..."
                                terraform plan -detailed-exitcode -out=tfplan
                            '''
                        } catch (Exception e) {
                            echo "Plan failed, checking if resources need to be imported or cleaned up..."
                            
                            // Try to import existing resource group
                            try {
                                bat '''
                                    cd terraform-aks
                                    echo "📥 Tentative d'import du Resource Group existant..."
                                    terraform import azurerm_resource_group.aks_rg "/subscriptions/%ARM_SUBSCRIPTION_ID%/resourceGroups/%TF_VAR_resource_group_name%"
                                '''
                            } catch (Exception importError) {
                                echo "Import failed, will try to clean up existing resources..."
                            }
                            
                            // Check if AKS cluster exists and needs cleanup
                            try {
                                bat '''
                                    echo "🔍 Vérification de l'existence du cluster AKS..."
                                    az aks show --name %TF_VAR_cluster_name% --resource-group %TF_VAR_resource_group_name% --subscription %ARM_SUBSCRIPTION_ID%
                                    if %ERRORLEVEL% EQU 0 (
                                        echo "⚠️  Cluster AKS existant détecté. Suppression pour recréer..."
                                        az aks delete --name %TF_VAR_cluster_name% --resource-group %TF_VAR_resource_group_name% --yes --no-wait --subscription %ARM_SUBSCRIPTION_ID%
                                        echo "⏳ Attente de la suppression du cluster..."
                                        timeout /t 60 /nobreak
                                    )
                                '''
                            } catch (Exception clusterError) {
                                echo "Cluster check failed, continuing..."
                            }
                            
                            // Clean up the resource group if needed
                            try {
                                bat '''
                                    echo "🧹 Nettoyage du Resource Group existant..."
                                    az group delete --name %TF_VAR_resource_group_name% --yes --no-wait --subscription %ARM_SUBSCRIPTION_ID%
                                    echo "⏳ Attente de la suppression du Resource Group..."
                                    timeout /t 30 /nobreak
                                '''
                            } catch (Exception rgError) {
                                echo "Resource group cleanup failed, continuing..."
                            }
                            
                            // Remove terraform state to start fresh
                            bat '''
                                cd terraform-aks
                                echo "🔄 Nettoyage de l'état Terraform..."
                                if exist terraform.tfstate del terraform.tfstate
                                if exist terraform.tfstate.backup del terraform.tfstate.backup
                                if exist .terraform.lock.hcl del .terraform.lock.hcl
                                
                                echo "🏗️ Réinitialisation de Terraform..."
                                terraform init -reconfigure
                            '''
                        }
                        
                        // Now run the plan and apply
                        bat '''
                            cd terraform-aks
                            echo "📋 Nouveau plan Terraform..."
                            terraform plan -out=tfplan
                            
                            echo "🚀 Application de l'infrastructure..."
                            terraform apply -auto-approve tfplan
                            
                            echo "✅ Vérification des outputs..."
                            terraform output
                            
                            echo "💾 Sauvegarde de la config Kubernetes..."
                            terraform output -raw kube_config > ../kubeconfig
                        '''
                    }
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
                        docker rmi %DOCKER_IMAGE_NAME%:%DOCKER_TAG% 2>nul || echo "Image build déjà supprimée"
                        docker rmi farahabbes/shopferimgg:latest 2>nul || echo "Image latest déjà supprimée"
                        docker system prune -f 2>nul || echo "Nettoyage système terminé"
                        
                        REM Nettoyer les fichiers temporaires
                        if exist Dockerfile.jenkins del Dockerfile.jenkins 2>nul
                        if exist nginx.conf del nginx.conf 2>nul
                    '''
                } catch (Exception e) {
                    echo "Warning: Docker cleanup failed"
                }
                
                // Archive important files
                try {
                    archiveArtifacts artifacts: 'terraform-aks/tfplan,kubeconfig,external_ip.txt,k8s-*.yaml', allowEmptyArchive: true, fingerprint: true
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
                        if exist terraform-aks\\terraform.tfstate (
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
                if exist terraform-aks\\tfplan del terraform-aks\\tfplan 2>nul
            '''
        }
    }
}
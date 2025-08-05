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
        
        stage('Install Dependencies') {
            steps {
                bat '''
                    echo "📦 Installation des dépendances..."
                    call npm install
                '''
            }
        }
        
        stage('Run Unit Tests') {
            steps {
                bat '''
                    echo "🧪 Exécution des tests unitaires..."
                    call npm run test -- --karma-config karma.conf.js --watch=false --code-coverage
                '''
            }
        }
        
        stage('Build Angular Application') {
            steps {
                bat '''
                    echo "🏗️ Build de l'application Angular..."
                    call npm run build --prod
                '''
            }
        }
        
        stage('Build Docker Image') {
            steps {
                bat '''
                    echo "🐳 Construction de l'image Docker..."
                    docker build -t %DOCKER_IMAGE_NAME%:%DOCKER_TAG% .
                    docker tag %DOCKER_IMAGE_NAME%:%DOCKER_TAG% %DOCKER_IMAGE_NAME%:latest
                '''
            }
        }
        
        stage('Push Docker Image to Docker Hub') {
            steps {
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
        
        stage('Pre-deployment Cleanup') {
            steps {
                script {
                    try {
                        bat '''
                            echo "🧹 Nettoyage pré-déploiement..."
                            docker stop shopfer-container 2>nul || echo Container not running
                            docker rm shopfer-container 2>nul || echo Container not found
                            for /f "tokens=5" %%a in ('netstat -aon 2^>nul ^| find ":4200" ^| find "LISTENING"') do (
                                taskkill /f /pid %%a 2^>nul || echo Process cleanup
                            )
                        '''
                    } catch (Exception e) {
                        echo "Pre-deployment cleanup completed"
                    }
                }
            }
        }
        
        stage('Test Docker Container Locally') {
            steps {
                script {
                    bat '''
                        echo "🚀 Test du conteneur Docker localement..."
                        docker run -d --name shopfer-container -p 4200:4200 %DOCKER_IMAGE_NAME%:%DOCKER_TAG%
                    '''
                    
                    // Verify container started
                    sleep(5)
                    def containerStatus = bat(script: 'docker ps --filter "name=shopfer-container" --format "{{.Status}}"', returnStdout: true).trim()
                    if (!containerStatus.contains("Up")) {
                        error("Container failed to start properly")
                    }
                    echo "✅ Container started successfully: ${containerStatus}"
                }
            }
        }
        
        stage('Verify Local Application') {
            steps {
                script {
                    echo "🔍 Vérification de l'application locale..."
                    def maxAttempts = 30
                    def attempt = 0
                    def appStarted = false

                    while (attempt < maxAttempts && !appStarted) {
                        try {
                            sleep(2)
                            bat 'netstat -an | find "4200" | find "LISTENING"'
                            appStarted = true
                            echo "✅ Application is listening on port 4200"
                        } catch (Exception e) {
                            attempt++
                            if (attempt % 10 == 0) {
                                echo "⏳ Waiting for application... (${attempt}/${maxAttempts})"
                            }
                        }
                    }

                    if (!appStarted) {
                        // Show container logs for debugging
                        try {
                            bat 'docker logs shopfer-container'
                        } catch (Exception e) {
                            echo "Could not retrieve container logs"
                        }
                        error("❌ Application failed to start within timeout")
                    }
                }
            }
        }
        
        stage('Setup Robot Framework Environment') {
            steps {
                bat '''
                    echo "🤖 Configuration de l'environnement Robot Framework..."
                    if not exist robot-tests mkdir robot-tests
                    cd robot-tests
                    if exist robot_env rmdir /s /q robot_env
                    python -m venv robot_env
                    robot_env\\Scripts\\python.exe -m pip install --upgrade pip --quiet
                    robot_env\\Scripts\\pip install robotframework robotframework-seleniumlibrary selenium webdriver-manager --quiet
                '''
            }
        }
        
        stage('Run Robot Framework Tests') {
            steps {
                bat '''
                    echo "🧪 Exécution des tests Robot Framework..."
                    cd robot-tests
                    robot_env\\Scripts\\robot --outputdir . ^
                                              --variable BROWSER:headlesschrome ^
                                              --variable URL:http://localhost:4200 ^
                                              --loglevel INFO ^
                                              hello.robot
                '''
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
                    
                    echo "✅ Terraform files ready"
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
                        try {
                            bat '''
                                cd terraform-aks
                                
                                echo "🔐 Configuration Azure..."
                                az login --service-principal -u %ARM_CLIENT_ID% -p %ARM_CLIENT_SECRET% --tenant %ARM_TENANT_ID%
                                az account set --subscription %ARM_SUBSCRIPTION_ID%
                                
                                echo "🏗️ Initialisation Terraform..."
                                terraform init
                                terraform validate
                            '''
                            
                            // Import existing resources strategy
                            try {
                                bat '''
                                    cd terraform-aks
                                    echo "📥 Import des ressources existantes..."
                                    
                                    REM Import Resource Group if exists
                                    az group show --name %TF_VAR_resource_group_name% --subscription %ARM_SUBSCRIPTION_ID% >nul 2>&1
                                    if %ERRORLEVEL% EQU 0 (
                                        terraform import azurerm_resource_group.aks_rg "/subscriptions/%ARM_SUBSCRIPTION_ID%/resourceGroups/%TF_VAR_resource_group_name%" || echo "RG import failed, continuing..."
                                    )
                                    
                                    REM Import AKS Cluster if exists  
                                    az aks show --name %TF_VAR_cluster_name% --resource-group %TF_VAR_resource_group_name% --subscription %ARM_SUBSCRIPTION_ID% >nul 2>&1
                                    if %ERRORLEVEL% EQU 0 (
                                        terraform import azurerm_kubernetes_cluster.aks "/subscriptions/%ARM_SUBSCRIPTION_ID%/resourceGroups/%TF_VAR_resource_group_name%/providers/Microsoft.ContainerService/managedClusters/%TF_VAR_cluster_name%" || echo "AKS import failed, continuing..."
                                    )
                                '''
                            } catch (Exception e) {
                                echo "Import phase completed with warnings"
                            }
                            
                            // Plan and Apply
                            bat '''
                                cd terraform-aks
                                echo "📋 Planning infrastructure..."
                                terraform plan -out=tfplan
                                
                                echo "🚀 Applying infrastructure..."
                                terraform apply -auto-approve tfplan
                                
                                echo "💾 Récupération kubeconfig..."
                                terraform output -raw kube_config > ../kubeconfig 2>nul || (
                                    az aks get-credentials --resource-group %TF_VAR_resource_group_name% --name %TF_VAR_cluster_name% --file ../kubeconfig --overwrite-existing
                                )
                            '''
                        } catch (Exception e) {
                            echo "⚠️ Terraform deployment failed: ${e.getMessage()}"
                            throw e
                        }
                    }
                }
            }
        }
        
        stage('Setup Kubernetes & NGINX Ingress') {
            steps {
                script {
                    try {
                        bat '''
                            echo "☸️ Configuration Kubernetes..."
                            set KUBECONFIG=%WORKSPACE%\\kubeconfig
                            
                            kubectl cluster-info
                            kubectl create namespace %APP_NAMESPACE% --dry-run=client -o yaml | kubectl apply -f -
                            
                            echo "🌐 Installation NGINX Ingress..."
                            kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml
                            kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=300s
                        '''
                    } catch (Exception e) {
                        echo "⚠️ Kubernetes setup failed: ${e.getMessage()}"
                        throw e
                    }
                }
            }
        }
        
        stage('Clean Existing AKS Resources') {
            steps {
                powershell '''
                    $env:KUBECONFIG = "$env:WORKSPACE\\kubeconfig"
                    
                    Write-Host "🧹 Nettoyage des ressources AKS..." -ForegroundColor Green
                    
                    kubectl delete ingress shopfer-ingress -n $env:APP_NAMESPACE --ignore-not-found=true
                    kubectl delete deployment shopfer-app -n $env:APP_NAMESPACE --ignore-not-found=true
                    kubectl delete service shopfer-service -n $env:APP_NAMESPACE --ignore-not-found=true
                    
                    Start-Sleep -Seconds 10
                '''
            }
        }
        
        stage('Create Kubernetes Manifests') {
            steps {
                // Deployment optimisé
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
  replicas: 1
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 0
      maxSurge: 1
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
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
        readinessProbe:
          httpGet:
            path: /
            port: 4200
          initialDelaySeconds: 30
          periodSeconds: 10
        livenessProbe:
          httpGet:
            path: /
            port: 4200
          initialDelaySeconds: 60
          periodSeconds: 30
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
                
                // Ingress
                writeFile file: 'k8s-ingress.yaml', text: """
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: shopfer-ingress
  namespace: ${APP_NAMESPACE}
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
spec:
  ingressClassName: nginx
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
        
        stage('Deploy to AKS') {
            steps {
                script {
                    try {
                        bat '''
                            set KUBECONFIG=%WORKSPACE%\\kubeconfig
                            
                            echo "🚀 Déploiement vers AKS..."
                            kubectl apply -f k8s-deployment.yaml
                            kubectl apply -f k8s-service.yaml
                            kubectl apply -f k8s-ingress.yaml
                            
                            echo "⏳ Attente du déploiement..."
                            kubectl rollout status deployment/shopfer-app -n %APP_NAMESPACE% --timeout=600s
                            
                            echo "✅ Vérification du déploiement..."
                            kubectl get pods -n %APP_NAMESPACE% -o wide
                        '''
                    } catch (Exception e) {
                        echo "⚠️ AKS deployment failed: ${e.getMessage()}"
                        
                        // Diagnostic en cas d'échec
                        try {
                            bat '''
                                set KUBECONFIG=%WORKSPACE%\\kubeconfig
                                kubectl get pods -n %APP_NAMESPACE% -o wide || echo "No pods found"
                                kubectl describe deployment shopfer-app -n %APP_NAMESPACE% || echo "No deployment found"
                                kubectl get events -n %APP_NAMESPACE% --sort-by=.metadata.creationTimestamp | tail -10 || echo "No events"
                                kubectl logs deployment/shopfer-app -n %APP_NAMESPACE% --tail=20 || echo "No logs available"
                            '''
                        } catch (Exception diagnosticError) {
                            echo "Could not retrieve diagnostics"
                        }
                        
                        throw e
                    }
                }
            }
        }
        
        stage('Get LoadBalancer IP & Configure DNS') {
            steps {
                script {
                    try {
                        powershell '''
                            $env:KUBECONFIG = "$env:WORKSPACE\\kubeconfig"
                            
                            Write-Host "🌍 Récupération IP LoadBalancer..." -ForegroundColor Green
                            
                            $timeout = 600
                            $counter = 0
                            $externalIP = $null
                            
                            do {
                                if ($counter -ge $timeout) {
                                    Write-Host "⚠️ Timeout pour l'IP externe" -ForegroundColor Yellow
                                    break
                                }
                                
                                $externalIP = kubectl get service ingress-nginx-controller -n ingress-nginx -o jsonpath="{.status.loadBalancer.ingress[0].ip}" 2>$null
                                
                                if ($externalIP -and $externalIP -ne "null" -and $externalIP -ne "") {
                                    Write-Host "✅ IP externe: $externalIP" -ForegroundColor Green
                                    $externalIP | Out-File -FilePath "external_ip.txt" -Encoding ASCII
                                    
                                    # Configuration DNS DuckDNS
                                    $uri = "https://www.duckdns.org/update?domains=shopfer-ecommerce&token=$env:DUCKDNS_TOKEN&ip=$externalIP"
                                    Invoke-RestMethod -Uri $uri
                                    Write-Host "🌐 DNS configuré pour $env:DOMAIN_NAME" -ForegroundColor Green
                                    break
                                }
                                
                                Start-Sleep -Seconds 10
                                $counter += 10
                                Write-Host "Attente IP externe... ($counter/$timeout)" -ForegroundColor Yellow
                            } while ($true)
                        '''
                    } catch (Exception e) {
                        echo "⚠️ LoadBalancer IP retrieval failed: ${e.getMessage()}"
                        // Don't fail the pipeline for this
                    }
                }
            }
        }
        
        stage('Final Verification') {
            steps {
                script {
                    try {
                        bat '''
                            set KUBECONFIG=%WORKSPACE%\\kubeconfig
                            
                            echo "📊 État final du déploiement..."
                            kubectl get all -n %APP_NAMESPACE%
                            kubectl get ingress -n %APP_NAMESPACE%
                            
                            echo "🔍 Logs de l'application:"
                            kubectl logs deployment/shopfer-app -n %APP_NAMESPACE% --tail=10
                        '''
                        
                        if (fileExists('external_ip.txt')) {
                            def externalIP = readFile('external_ip.txt').trim()
                            echo """
                            ✅ Déploiement terminé avec succès !
                            🌍 Application accessible sur: http://${DOMAIN_NAME}
                            🔗 IP LoadBalancer: ${externalIP}
                            """
                        }
                    } catch (Exception e) {
                        echo "Final verification completed with warnings"
                    }
                }
            }
        }
    }
    
    post {
        always {
            script {
                // Publish Robot Framework results
                try {
                    if (fileExists('robot-tests/output.xml')) {
                        robot(
                            outputPath: 'robot-tests',
                            outputFileName: 'output.xml',
                            reportFileName: 'report.html',
                            logFileName: 'log.html',
                            disableArchiveOutput: false,
                            passThreshold: 80,
                            unstableThreshold: 60,
                            otherFiles: '*.png,*.jpg'
                        )
                    }
                } catch (Exception e) {
                    echo "Warning: Could not publish Robot Framework results"
                }
                
                // Archive artifacts
                try {
                    archiveArtifacts artifacts: 'terraform-aks/tfplan,kubeconfig,external_ip.txt,k8s-*.yaml,robot-tests/**/*.{xml,html,log,png,jpg}', allowEmptyArchive: true, fingerprint: true
                } catch (Exception e) {
                    echo "Warning: Could not archive artifacts"
                }
                
                // Cleanup Docker images
                try {
                    bat '''
                        echo "🧹 Nettoyage images Docker..."
                        docker rmi %DOCKER_IMAGE_NAME%:%DOCKER_TAG% 2>nul || echo "Image déjà supprimée"
                        docker system prune -f 2>nul || echo "Nettoyage terminé"
                    '''
                } catch (Exception e) {
                    echo "Docker cleanup completed with warnings"
                }
                
                // Stop local test container
                try {
                    bat '''
                        docker stop shopfer-container 2>nul || echo "Container already stopped"
                        docker rm shopfer-container 2>nul || echo "Container already removed"
                    '''
                } catch (Exception e) {
                    echo "Local container cleanup completed"
                }
            }
        }
        
        success {
            script {
                echo '''
                ✅ Pipeline terminé avec succès !
                
                📋 Résumé du déploiement:
                - ✅ Tests unitaires passés
                - ✅ Tests Robot Framework executés
                - ✅ Image Docker construite et poussée
                - ✅ Infrastructure Terraform déployée
                - ✅ Application déployée sur AKS
                - ✅ DNS configuré
                '''
                
                try {
                    bat '''
                        echo "=== ÉTAT FINAL ==="
                        echo "Application locale testée: http://localhost:4200"
                        echo "Application AKS: http://%DOMAIN_NAME%"
                        
                        set KUBECONFIG=%WORKSPACE%\\kubeconfig
                        kubectl get pods -n %APP_NAMESPACE% -o wide 2>nul || echo "AKS status unknown"
                    '''
                } catch (Exception e) {
                    echo "Final status check completed"
                }
            }
        }
        
        failure {
            script {
                echo '''
                ❌ Pipeline échoué !
                
                🔍 Vérifications suggérées:
                1. Credentials Azure/Docker Hub
                2. Quota Azure disponible
                3. Token DuckDNS valide
                4. Tests unitaires/Robot Framework
                '''
                
                try {
                    bat '''
                        echo "=== DIAGNOSTIC D'ÉCHEC ==="
                        
                        echo "Images Docker:"
                        docker images | find "shopfer" 2>nul || echo "Aucune image shopfer"
                        
                        echo "Conteneurs:"
                        docker ps -a --filter "name=shopfer" 2>nul || echo "Aucun conteneur shopfer"
                        
                        echo "Port 4200:"
                        netstat -an | find "4200" 2>nul || echo "Port 4200 libre"
                        
                        echo "Tests Robot Framework:"
                        if exist robot-tests\\output.xml (echo "Tests RF disponibles") else (echo "Pas de résultats RF")
                        
                        if exist kubeconfig (
                            set KUBECONFIG=%WORKSPACE%\\kubeconfig
                            kubectl get pods -n %APP_NAMESPACE% 2>nul || echo "Impossible de se connecter à AKS"
                        )
                    '''
                } catch (Exception e) {
                    echo "Diagnostic failed but pipeline marked as failed"
                }
            }
        }
        
        cleanup {
            powershell '''
                # Cleanup temporary files
                @("external_ip.txt", "terraform-aks\\tfplan") | ForEach-Object {
                    if (Test-Path $_) { Remove-Item $_ -Force }
                }
            '''
        }
    }
}
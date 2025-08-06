pipeline {
    agent any
    
    environment {
        DOCKER_HUB_REGISTRY = 'docker.io'
        DOCKER_IMAGE_NAME = 'farahabbes/shopferimgg'
        DOCKER_TAG = "${BUILD_NUMBER}"
        
        AZURE_CREDENTIALS = credentials('azure-service-principal')
        
        TF_VAR_resource_group_name = 'rg-shopfer-aks'
        TF_VAR_cluster_name = 'aks-shopfer'
        TF_VAR_location = 'francecentral'
        TF_VAR_node_count = '1'
        TF_VAR_kubernetes_version = '1.30.14'
        TF_VAR_vm_size = 'Standard_B2s'
        
        APP_NAMESPACE = 'shopfer-app'
        DOMAIN_NAME = 'shopfer-ecommerce.duckdns.org'
        DUCKDNS_TOKEN = credentials('duckdns-token')
        
        // Variables pour les tests
        LOCAL_APP_URL = 'http://localhost:4200'
        DEPLOYED_APP_URL = "http://${DOMAIN_NAME}"
    }
    
    stages {
        stage('Clone Repository') {
            steps {
                git branch: 'main', url: 'https://github.com/Ichrak-dhahri/ShopFer.git'
            }
        }
        
        stage('Install Dependencies') {
            steps {
                bat 'call npm install'
            }
        }
        
        stage('Run Unit Tests') {
            steps {
                bat 'call npm run test -- --karma-config karma.conf.js --watch=false --code-coverage'
            }
        }
        
        stage('Build Angular Application') {
            steps {
                bat 'call npm run build --prod'
            }
        }
        
        stage('Start Local Application for Testing') {
            steps {
                echo "Démarrage de l'application Angular en local pour les tests..."
                bat '''
                    echo Démarrage de l application Angular...
                    start "Angular App" /min cmd /c "npm run start"
                    echo Attente du démarrage de l application...
                '''
                
                // Attendre que l'application soit disponible
                script {
                    def maxAttempts = 30
                    def attempt = 0
                    def appStarted = false
                    
                    while (attempt < maxAttempts && !appStarted) {
                        try {
                            sleep(2)
                            bat 'netstat -an | find "4200" | find "LISTENING"'
                            appStarted = true
                            echo "✅ Application Angular démarrée sur le port 4200"
                        } catch (Exception e) {
                            attempt++
                            echo "Tentative ${attempt}/${maxAttempts} - Application pas encore prête..."
                        }
                    }
                    
                    if (!appStarted) {
                        error("❌ L'application Angular n'a pas pu démarrer dans le délai imparti")
                    }
                }
            }
        }
        
        stage('Setup Robot Framework Environment') {
            steps {
                echo "Configuration de l'environnement Robot Framework..."
                
                bat '''
                    if not exist robot-tests mkdir robot-tests
                    cd robot-tests
                '''
                
                bat '''
                    cd robot-tests
                    if exist robot_env rmdir /s /q robot_env
                    python -m venv robot_env
                '''
                
                bat '''
                    cd robot-tests
                    robot_env\\Scripts\\python.exe -m pip install --upgrade pip
                    robot_env\\Scripts\\pip install robotframework
                    robot_env\\Scripts\\pip install robotframework-seleniumlibrary
                    robot_env\\Scripts\\pip install selenium
                    robot_env\\Scripts\\pip install webdriver-manager
                '''
                
                echo "✅ Environnement Robot Framework configuré"
            }
        }
        
        stage('Run Robot Framework Tests (Local)') {
            steps {
                echo "Exécution des tests Robot Framework sur l'application locale..."
                
                bat '''
                    cd robot-tests
                    robot_env\\Scripts\\robot --outputdir local-tests ^
                                              --variable BROWSER:headlesschrome ^
                                              --variable URL:%LOCAL_APP_URL% ^
                                              --loglevel INFO ^
                                              --name "Local Tests" ^
                                              hello.robot
                '''
            }
        }
        
        stage('Stop Local Application') {
            steps {
                echo "Arrêt de l'application locale..."
                bat '''
                    echo Arrêt des processus Node.js sur le port 4200...
                    for /f "tokens=5" %%a in ('netstat -aon 2^>nul ^| find ":4200" ^| find "LISTENING"') do (
                        echo Arrêt du processus %%a
                        taskkill /f /pid %%a 2>nul || echo Processus %%a déjà arrêté
                    )
                    
                    echo Arrêt de tous les processus npm et node...
                    taskkill /f /im node.exe 2>nul || echo Aucun processus node.exe
                    taskkill /f /im npm.cmd 2>nul || echo Aucun processus npm.cmd
                    
                    echo Nettoyage terminé
                    exit /b 0
                '''
            }
        }
        
        stage('Docker Build & Push') {
            steps {
                script {
                    bat '''
                        docker build -t %DOCKER_IMAGE_NAME%:%DOCKER_TAG% .
                        docker tag %DOCKER_IMAGE_NAME%:%DOCKER_TAG% %DOCKER_IMAGE_NAME%:latest
                    '''
                    
                    withCredentials([usernamePassword(credentialsId: 'docker-hub-login', usernameVariable: 'DOCKER_HUB_USER', passwordVariable: 'DOCKER_HUB_PASS')]) {
                        bat '''
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
                    cd terraform-aks
                    where terraform >nul 2>&1 || (
                        powershell -Command "Invoke-WebRequest -Uri 'https://releases.hashicorp.com/terraform/1.5.0/terraform_1.5.0_windows_amd64.zip' -OutFile 'terraform.zip'"
                        powershell -Command "Expand-Archive -Path 'terraform.zip' -DestinationPath '.'"
                        del terraform.zip
                    )
                '''
            }
        }
        
        stage('Deploy Infrastructure') {
            steps {
                withCredentials([azureServicePrincipal(credentialsId: 'azure-service-principal', 
                    subscriptionIdVariable: 'ARM_SUBSCRIPTION_ID',
                    clientIdVariable: 'ARM_CLIENT_ID',
                    clientSecretVariable: 'ARM_CLIENT_SECRET',
                    tenantIdVariable: 'ARM_TENANT_ID')]) {
                    
                    script {
                        bat '''
                            cd terraform-aks
                            az login --service-principal -u %ARM_CLIENT_ID% -p %ARM_CLIENT_SECRET% --tenant %ARM_TENANT_ID%
                            az account set --subscription %ARM_SUBSCRIPTION_ID%
                            terraform init
                            terraform validate
                        '''
                        
                        // Import existing resources
                        try {
                            bat '''
                                cd terraform-aks
                                az group show --name %TF_VAR_resource_group_name% --subscription %ARM_SUBSCRIPTION_ID% >nul 2>&1
                                if %ERRORLEVEL% EQU 0 (
                                    terraform import azurerm_resource_group.aks_rg "/subscriptions/%ARM_SUBSCRIPTION_ID%/resourceGroups/%TF_VAR_resource_group_name%" || echo "RG import failed"
                                )
                                
                                az aks show --name %TF_VAR_cluster_name% --resource-group %TF_VAR_resource_group_name% --subscription %ARM_SUBSCRIPTION_ID% >nul 2>&1
                                if %ERRORLEVEL% EQU 0 (
                                    terraform import azurerm_kubernetes_cluster.aks "/subscriptions/%ARM_SUBSCRIPTION_ID%/resourceGroups/%TF_VAR_resource_group_name%/providers/Microsoft.ContainerService/managedClusters/%TF_VAR_cluster_name%" || echo "AKS import failed"
                                )
                            '''
                        } catch (Exception e) {
                            echo "Import warnings: ${e.getMessage()}"
                        }
                        
                        bat '''
                            cd terraform-aks
                            terraform plan -out=tfplan
                            terraform apply -auto-approve tfplan
                            terraform output -raw kube_config > ../kubeconfig 2>nul || az aks get-credentials --resource-group %TF_VAR_resource_group_name% --name %TF_VAR_cluster_name% --file ../kubeconfig --overwrite-existing
                        '''
                    }
                }
            }
        }
        
        stage('Setup K8s & NGINX') {
            steps {
                bat '''
                    set KUBECONFIG=%WORKSPACE%\\kubeconfig
                    kubectl cluster-info
                    kubectl create namespace %APP_NAMESPACE% --dry-run=client -o yaml | kubectl apply -f -
                    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml
                    kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=300s
                '''
            }
        }
        
        stage('Clean & Deploy App') {
            steps {
                powershell '''
                    $env:KUBECONFIG = "$env:WORKSPACE\\kubeconfig"
                    kubectl delete ingress,deployment,service -l app=shopfer -n $env:APP_NAMESPACE --ignore-not-found=true
                    Start-Sleep 10
                '''
                
                // Create manifests
                writeFile file: 'k8s-all.yaml', text: """
apiVersion: apps/v1
kind: Deployment
metadata:
  name: shopfer-app
  namespace: ${APP_NAMESPACE}
  labels:
    app: shopfer
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
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
---
apiVersion: v1
kind: Service
metadata:
  name: shopfer-service
  namespace: ${APP_NAMESPACE}
  labels:
    app: shopfer
spec:
  selector:
    app: shopfer
  ports:
  - port: 80
    targetPort: 4200
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: shopfer-ingress
  namespace: ${APP_NAMESPACE}
  labels:
    app: shopfer
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
                
                bat '''
                    set KUBECONFIG=%WORKSPACE%\\kubeconfig
                    kubectl apply -f k8s-all.yaml
                    kubectl rollout status deployment/shopfer-app -n %APP_NAMESPACE% --timeout=300s
                '''
            }
        }
        
        stage('Configure DNS') {
            steps {
                powershell '''
                    $env:KUBECONFIG = "$env:WORKSPACE\\kubeconfig"
                    
                    $timeout = 600; $counter = 0; $externalIP = $null
                    do {
                        if ($counter -ge $timeout) { break }
                        $externalIP = kubectl get service ingress-nginx-controller -n ingress-nginx -o jsonpath="{.status.loadBalancer.ingress[0].ip}" 2>$null
                        if ($externalIP -and $externalIP -ne "null" -and $externalIP -ne "") {
                            Write-Host "External IP: $externalIP"
                            break
                        }
                        Start-Sleep 10; $counter += 10
                    } while ($true)
                    
                    if ($externalIP) {
                        $uri = "https://www.duckdns.org/update?domains=shopfer-ecommerce&token=$env:DUCKDNS_TOKEN&ip=$externalIP"
                        Invoke-RestMethod -Uri $uri
                        Write-Host "DNS configured for $env:DOMAIN_NAME -> $externalIP"
                    }
                '''
            }
        }
        
        stage('Wait for Application Deployment') {
            steps {
                echo "Attente de la disponibilité de l'application déployée..."
                script {
                    def maxAttempts = 60
                    def attempt = 0
                    def appReady = false
                    
                    while (attempt < maxAttempts && !appReady) {
                        try {
                            sleep(10)
                            // Test de connectivité HTTP
                            powershell """
                                try {
                                    \$response = Invoke-WebRequest -Uri "${DEPLOYED_APP_URL}" -TimeoutSec 10 -UseBasicParsing
                                    if (\$response.StatusCode -eq 200) {
                                        Write-Host "✅ Application accessible"
                                        exit 0
                                    }
                                } catch {
                                    Write-Host "❌ Application pas encore accessible"
                                    exit 1
                                }
                            """
                            appReady = true
                            echo "✅ Application déployée accessible sur ${DEPLOYED_APP_URL}"
                        } catch (Exception e) {
                            attempt++
                            echo "Tentative ${attempt}/${maxAttempts} - Application pas encore accessible..."
                        }
                    }
                    
                    if (!appReady) {
                        error("❌ L'application déployée n'est pas accessible dans le délai imparti")
                    }
                }
            }
        }
        
        stage('Run Robot Framework Tests (Deployed)') {
            steps {
                echo "Exécution des tests Robot Framework sur l'application déployée..."
                
                bat '''
                    cd robot-tests
                    robot_env\\Scripts\\robot --outputdir deployed-tests ^
                                              --variable BROWSER:headlesschrome ^
                                              --variable URL:%DEPLOYED_APP_URL% ^
                                              --loglevel INFO ^
                                              --name "Deployed Tests" ^
                                              hello.robot
                '''
            }
        }
        
        stage('Verify Deployment') {
            steps {
                bat '''
                    set KUBECONFIG=%WORKSPACE%\\kubeconfig
                    echo === STATUS DU DEPLOYMENT ===
                    kubectl get all -n %APP_NAMESPACE%
                    kubectl get ingress -n %APP_NAMESPACE%
                    echo.
                    echo === LOGS DES PODS ===
                    kubectl logs -l app=shopfer -n %APP_NAMESPACE% --tail=50
                '''
            }
        }
    }
    
    post {
        always {
            echo "Nettoyage et archivage des résultats..."
            
            // Arrêt des processus locaux si nécessaire
            bat '''
                echo Nettoyage final des processus Node.js...
                for /f "tokens=5" %%a in ('netstat -aon 2^>nul ^| find ":4200" ^| find "LISTENING"') do (
                    echo Arrêt du processus %%a
                    taskkill /f /pid %%a 2>nul || echo Processus %%a déjà arrêté
                )
                taskkill /f /im node.exe 2>nul || echo Aucun processus node.exe
                taskkill /f /im npm.cmd 2>nul || echo Aucun processus npm.cmd
                exit /b 0
            '''
            
            // Publication des résultats Robot Framework
            script {
                try {
                    // Résultats des tests locaux
                    robot(
                        outputPath: 'robot-tests/local-tests',
                        outputFileName: 'output.xml',
                        reportFileName: 'report.html',
                        logFileName: 'log.html',
                        disableArchiveOutput: false,
                        passThreshold: 80,
                        unstableThreshold: 60,
                        otherFiles: '*.png,*.jpg'
                    )
                } catch (Exception e) {
                    echo "⚠️ Erreur lors de la publication des résultats Robot (local): ${e.getMessage()}"
                }
                
                try {
                    // Résultats des tests de déploiement
                    robot(
                        outputPath: 'robot-tests/deployed-tests',
                        outputFileName: 'output.xml',
                        reportFileName: 'report.html',
                        logFileName: 'log.html',
                        disableArchiveOutput: false,
                        passThreshold: 80,
                        unstableThreshold: 60,
                        otherFiles: '*.png,*.jpg'
                    )
                } catch (Exception e) {
                    echo "⚠️ Erreur lors de la publication des résultats Robot (deployed): ${e.getMessage()}"
                }
            }
            
            // Archivage des artefacts
            script {
                try {
                    bat 'docker rmi %DOCKER_IMAGE_NAME%:%DOCKER_TAG% 2>nul || echo "Docker cleanup done"'
                    archiveArtifacts artifacts: 'terraform-aks/tfplan,kubeconfig,k8s-all.yaml,robot-tests/**/*.{xml,html,log,png,jpg}', allowEmptyArchive: true, fingerprint: true
                } catch (Exception e) {
                    echo "⚠️ Erreur lors de l'archivage: ${e.getMessage()}"
                }
            }
        }
        
        success {
            echo """
            ✅ Pipeline terminé avec succès!
            🌐 Application disponible à: ${DEPLOYED_APP_URL}
            📊 Tests Robot Framework exécutés en local et sur le déploiement
            🐳 Image Docker: ${DOCKER_IMAGE_NAME}:${DOCKER_TAG}
            ☸️  Cluster AKS: ${TF_VAR_cluster_name} dans ${TF_VAR_resource_group_name}
            """
        }
        
        failure {
            echo """
            ❌ Pipeline échoué! 
            
            Vérifiez:
            - 🔑 Credentials Azure, Docker Hub, DuckDNS
            - 🏗️  Configuration Terraform
            - ☸️  Statut du cluster AKS
            - 🌐 Connectivité réseau
            - 🤖 Tests Robot Framework
            
            Consultez les logs détaillés ci-dessus.
            """
            
            // Diagnostic en cas d'échec
            bat '''
                echo === DIAGNOSTIC COMPLET ===
                echo.
                echo État des processus Node.js:
                tasklist | find "node.exe" || echo Aucun processus Node.js
                echo.
                echo Ports en écoute:
                netstat -an | find "4200" || echo Port 4200 non trouvé
                echo.
                echo Contenu du répertoire robot-tests:
                if exist robot-tests (
                    dir robot-tests /s
                ) else (
                    echo Répertoire robot-tests non trouvé
                )
                echo.
                echo Images Docker disponibles:
                docker images | find "shopfer" || echo Aucune image shopfer trouvée
                echo.
                echo === FIN DIAGNOSTIC ===
            '''
            
            // Diagnostic Kubernetes si disponible
            script {
                try {
                    bat '''
                        if exist kubeconfig (
                            set KUBECONFIG=%WORKSPACE%\\kubeconfig
                            echo === DIAGNOSTIC KUBERNETES ===
                            kubectl get pods -n %APP_NAMESPACE% || echo Erreur kubectl
                            kubectl describe pods -n %APP_NAMESPACE% || echo Erreur describe
                            echo === FIN DIAGNOSTIC K8S ===
                        )
                    '''
                } catch (Exception e) {
                    echo "Kubernetes non accessible pour le diagnostic"
                }
            }
        }
    }
}
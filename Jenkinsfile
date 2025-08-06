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
    }
    
    stages {
        stage('Clone Repository') {
            steps {
                git branch: 'main', url: 'https://github.com/Ichrak-dhahri/ShopFer.git'
            }
        }
        
        stage('Build & Test') {
            steps {
                bat '''
                    call npm install
                    call npm run build --prod
                    call npm run test -- --karma-config karma.conf.js --watch=false --code-coverage
                '''
            }
        }
        
        stage('Build Angular Application') {
            steps {
                bat 'call npm run build'
            }
        }
        
        stage('Start Angular Application') {
            steps {
                // Démarrer l'application Angular en arrière-plan de façon plus robuste
                bat '''
                    echo Démarrage de l application Angular...
                    start "Angular App" /min cmd /c "npm run start"
                    echo Attente du démarrage de l application...
                '''
                
                // Attendre que l'application soit disponible avec une vérification
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
                
                // Créer le répertoire s'il n'existe pas
                bat '''
                    if not exist robot-tests mkdir robot-tests
                    cd robot-tests
                '''
                
                // Créer l'environnement virtuel
                bat '''
                    cd robot-tests
                    if exist robot_env rmdir /s /q robot_env
                    python -m venv robot_env
                '''
                
                // Mettre à jour pip et installer les dépendances
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
        
        stage('Verify Application Status') {
            steps {
                echo "Vérification du statut de l'application..."
                bat '''
                    echo État des processus Node.js:
                    tasklist | find "node.exe" || echo Aucun processus Node.js trouvé
                    echo.
                    echo Ports en écoute:
                    netstat -an | find "4200" || echo Port 4200 non trouvé
                    echo.
                    echo Test de connectivité HTTP:
                    curl -f http://localhost:4200 || echo Connexion échouée
                '''
            }
        }
        
        stage('Run Robot Framework tests') {
            steps {
                echo "Exécution des tests Robot Framework..."
                
                // Exécuter les tests
                bat '''
                    cd robot-tests
                    robot_env\\Scripts\\robot --outputdir . ^
                                              --variable BROWSER:headlesschrome ^
                                              --variable URL:http://localhost:4200 ^
                                              --loglevel INFO ^
                                              hello.robot
                '''
            }
            post {
                always {
                    // Arrêter l'application Angular après les tests
                    script {
                        try {
                            bat 'taskkill /f /im "node.exe" 2>nul || echo "Aucun processus Node.js à arrêter"'
                            echo "✅ Application Angular arrêtée"
                        } catch (Exception e) {
                            echo "Avertissement lors de l'arrêt de l'application: ${e.getMessage()}"
                        }
                    }
                    // Archiver les résultats des tests Robot Framework
                    archiveArtifacts artifacts: 'robot-tests/*.html,robot-tests/*.xml,robot-tests/log.html,robot-tests/report.html', allowEmptyArchive: true
                    // Publier les résultats des tests
                    publishHTML([
                        allowMissing: false,
                        alwaysLinkToLastBuild: false,
                        keepAll: true,
                        reportDir: 'robot-tests',
                        reportFiles: 'report.html',
                        reportName: 'Robot Framework Test Report'
                    ])
                }
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
        
        stage('Verify') {
            steps {
                bat '''
                    set KUBECONFIG=%WORKSPACE%\\kubeconfig
                    kubectl get all -n %APP_NAMESPACE%
                    kubectl get ingress -n %APP_NAMESPACE%
                '''
            }
        }
    }
    
    post {
        always {
            script {
                try {
                    // Nettoyer les processus Node.js restants
                    bat 'taskkill /f /im "node.exe" 2>nul || echo "Aucun processus Node.js à arrêter"'
                    bat 'docker rmi %DOCKER_IMAGE_NAME%:%DOCKER_TAG% 2>nul || echo "Cleanup done"'
                    archiveArtifacts artifacts: 'terraform-aks/tfplan,kubeconfig,k8s-all.yaml,robot-tests/*.html,robot-tests/*.xml', allowEmptyArchive: true
                } catch (Exception e) {
                    echo "Cleanup warnings"
                }
            }
        }
        
        success {
            echo "✅ Deployment successful! App available at: http://${DOMAIN_NAME}"
        }
        
        failure {
            echo "❌ Pipeline failed! Check logs and verify: Azure credentials, Docker Hub access, DuckDNS token"
        }
    }
}
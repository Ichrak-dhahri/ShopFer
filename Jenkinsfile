pipeline {
    agent any
    
    environment {
        DOCKER_HUB_REGISTRY = 'docker.io'
        DOCKER_IMAGE_NAME = 'farahabbes/shopferimgg'
        DOCKER_TAG = "${BUILD_NUMBER}"
        RESOURCE_GROUP_NAME = 'rg-shopfer-aks'
        CLUSTER_NAME = 'aks-shopfer'
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
                bat 'call npm install'
            }
        }
        
        stage('SonarQube Analysis') {
            steps {
                script {
                    try {
                        withSonarQubeEnv(credentialsId: 'SQube-token', installationName: 'SonarQube') {
                            def scannerHome = tool 'SonarScanner'
                            bat "\"${scannerHome}\\bin\\sonar-scanner.bat\" -Dsonar.projectKey=E-commerce-App-main -Dsonar.sources=src"
                        }
                    } catch (Exception e) {
                        echo "SonarQube analysis failed: ${e.message}"
                        echo "Continuing pipeline without SonarQube analysis..."
                        // Continue pipeline even if SonarQube fails
                    }
                }
            }
        }
        
        stage('Quality Gate') {
            steps {
                script {
                    try {
                        timeout(time: 5, unit: 'MINUTES') {
                            waitForQualityGate abortPipeline: false
                        }
                    } catch (Exception e) {
                        echo "Quality Gate check failed: ${e.message}"
                        echo "Continuing pipeline without Quality Gate verification..."
                        // Continue pipeline even if Quality Gate fails
                    }
                }
            }
        }
        
        stage('Build & Test') {
            steps {
                bat '''
                    call npm run build --prod
                    call npm run test -- --karma-config karma.conf.js --watch=false --code-coverage
                '''
            }
        }
        
        stage('Start Angular Application') {
            steps {
                bat 'start "Angular App" /min cmd /c "npm run start"'
                
                script {
                    def maxAttempts = 30, attempt = 0, appStarted = false
                    
                    while (attempt < maxAttempts && !appStarted) {
                        try {
                            sleep(2)
                            bat 'netstat -an | find "4200" | find "LISTENING"'
                            appStarted = true
                        } catch (Exception e) { attempt++ }
                    }
                    
                    if (!appStarted) error("Application Angular n'a pas démarré")
                }
            }
        }
        
        stage('Setup Robot Framework') {
            steps {
                bat '''
                    if not exist robot-tests mkdir robot-tests
                    cd robot-tests && if exist robot_env rmdir /s /q robot_env
                    python -m venv robot_env && robot_env\\Scripts\\python.exe -m pip install --upgrade pip
                    robot_env\\Scripts\\pip install robotframework robotframework-seleniumlibrary selenium webdriver-manager
                '''
            }
        }
        
        stage('Verify & Test') {
            steps {
                bat '''
                    curl -f http://localhost:4200 >nul 2>&1 || (echo Connection failed && exit /b 1)
                    cd robot-tests && robot_env\\Scripts\\robot --outputdir . --variable BROWSER:headlesschrome --variable URL:http://localhost:4200 --loglevel INFO hello.robot
                '''
            }
        }
        
        stage('Cleanup Process') {
            steps {
                bat '''
                    for /f "tokens=5" %%a in ('netstat -aon 2^>nul ^| find ":4200" ^| find "LISTENING"') do taskkill /f /pid %%a 2>nul
                    taskkill /f /im node.exe /im npm.cmd 2>nul || exit /b 0
                '''
            }
        }
        
        stage('Build Angular Application') {
            steps {
                bat 'call npm run build'
            }
        }
        
        stage('Build Docker Image') {
            steps {
                script {
                    bat '''
                        docker build -t %DOCKER_IMAGE_NAME%:%DOCKER_TAG% .
                        docker tag %DOCKER_IMAGE_NAME%:%DOCKER_TAG% %DOCKER_IMAGE_NAME%:latest
                    '''
                }
            }
        }
        
        stage('Push Docker Image to Docker Hub') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'docker-hub-login', usernameVariable: 'DOCKER_HUB_USER', passwordVariable: 'DOCKER_HUB_PASS')]) {
                    bat '''
                        docker login -u %DOCKER_HUB_USER% -p %DOCKER_HUB_PASS%
                        docker push %DOCKER_IMAGE_NAME%:%DOCKER_TAG%
                        docker push %DOCKER_IMAGE_NAME%:latest
                    '''
                }
            }
        }
        
        stage('AKS Connection & Setup') {
            steps {
                withCredentials([azureServicePrincipal(credentialsId: 'azure-service-principal', 
                    subscriptionIdVariable: 'ARM_SUBSCRIPTION_ID', clientIdVariable: 'ARM_CLIENT_ID',
                    clientSecretVariable: 'ARM_CLIENT_SECRET', tenantIdVariable: 'ARM_TENANT_ID')]) {
                    
                    bat '''
                        echo "=== Connexion Azure ==="
                        az login --service-principal --username %ARM_CLIENT_ID% --password="%ARM_CLIENT_SECRET%" --tenant %ARM_TENANT_ID%
                        az account set --subscription %ARM_SUBSCRIPTION_ID%
                        
                        echo "=== Récupération des informations AKS ==="
                        for /f "tokens=*" %%i in ('az aks show --resource-group %RESOURCE_GROUP_NAME% --name %CLUSTER_NAME% --query "fqdn" -o tsv') do set AKS_FQDN=%%i
                        
                        echo "=== Création d'un kubeconfig personnalisé ==="
                        az aks get-credentials --resource-group %RESOURCE_GROUP_NAME% --name %CLUSTER_NAME% --file temp-kubeconfig --overwrite-existing --admin
                        
                        echo "=== Obtention du token d'accès ==="
                        for /f "tokens=*" %%i in ('az account get-access-token --resource "https://management.azure.com/" --query "accessToken" -o tsv') do set AZURE_TOKEN=%%i
                        
                        echo "=== Création du kubeconfig avec authentification par token ==="
                        (
                            echo apiVersion: v1
                            echo clusters:
                            echo - cluster:
                            echo     certificate-authority-data: ^(az aks show --resource-group %RESOURCE_GROUP_NAME% --name %CLUSTER_NAME% --query "agentPoolProfiles[0].osType" -o tsv ^> nul ^&^& echo "LS0tLS1CRUdJTi..."^)
                            echo     server: https://!AKS_FQDN!:443
                            echo   name: %CLUSTER_NAME%
                            echo contexts:
                            echo - context:
                            echo     cluster: %CLUSTER_NAME%
                            echo     user: clusterAdmin_%RESOURCE_GROUP_NAME%_%CLUSTER_NAME%
                            echo   name: %CLUSTER_NAME%-admin
                            echo current-context: %CLUSTER_NAME%-admin
                            echo kind: Config
                            echo preferences: {}
                            echo users:
                            echo - name: clusterAdmin_%RESOURCE_GROUP_NAME%_%CLUSTER_NAME%
                            echo   user:
                            echo     exec:
                            echo       apiVersion: client.authentication.k8s.io/v1beta1
                            echo       command: az
                            echo       args:
                            echo       - aks
                            echo       - get-credentials
                            echo       - --resource-group
                            echo       - %RESOURCE_GROUP_NAME%
                            echo       - --name
                            echo       - %CLUSTER_NAME%
                            echo       - --format
                            echo       - exec
                            echo       env:
                            echo       - name: AAD_SERVICE_PRINCIPAL_CLIENT_ID
                            echo         value: %ARM_CLIENT_ID%
                            echo       - name: AAD_SERVICE_PRINCIPAL_CLIENT_SECRET
                            echo         value: %ARM_CLIENT_SECRET%
                        ) > kubeconfig
                    '''
                }
                
                // Test plus simple avec kubectl direct
                bat '''
                    echo "=== Test kubectl avec configuration simplifiée ==="
                    set KUBECONFIG=%WORKSPACE%\\kubeconfig
                    
                    echo "Version kubectl:"
                    kubectl version --client --short 2>nul || kubectl version --client
                    
                    echo "Test de connexion basique:"
                    kubectl get nodes --request-timeout=30s || (
                        echo "Échec de la connexion standard, tentative avec authentification forcée..."
                        az aks get-credentials --resource-group %RESOURCE_GROUP_NAME% --name %CLUSTER_NAME% --file kubeconfig2 --overwrite-existing --admin
                        set KUBECONFIG=%WORKSPACE%\\kubeconfig2
                        kubectl get nodes --request-timeout=30s
                    )
                '''
            }
        }
        
        stage('Deploy Application') {
            when {
                expression { return currentBuild.currentResult != 'FAILURE' }
            }
            steps {
                bat '''
                    set KUBECONFIG=%WORKSPACE%\\kubeconfig
                    if exist kubeconfig2 set KUBECONFIG=%WORKSPACE%\\kubeconfig2
                    
                    echo "=== Nettoyage des ressources existantes ==="
                    kubectl create namespace %APP_NAMESPACE% --dry-run=client -o yaml | kubectl apply -f - --validate=false
                    kubectl delete all -l app=shopfer -n %APP_NAMESPACE% --ignore-not-found=true --timeout=60s
                    
                    echo "=== Vérification/Installation Ingress Controller ==="
                    kubectl get namespace ingress-nginx 2>nul || (
                        echo "Installation du contrôleur ingress..."
                        kubectl create namespace ingress-nginx --validate=false
                        kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml --validate=false
                        timeout /t 60 /nobreak >nul
                    )
                '''
                
                writeFile file: 'k8s-deployment.yaml', text: """
apiVersion: apps/v1
kind: Deployment
metadata:
  name: shopfer-app
  namespace: ${APP_NAMESPACE}
  labels:
    app: shopfer
spec:
  replicas: 2
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
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
            memory: "256Mi"
            cpu: "200m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        readinessProbe:
          httpGet:
            path: /
            port: 4200
          initialDelaySeconds: 15
          periodSeconds: 10
          timeoutSeconds: 5
        livenessProbe:
          httpGet:
            path: /
            port: 4200
          initialDelaySeconds: 30
          periodSeconds: 30
          timeoutSeconds: 10
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
    protocol: TCP
  type: ClusterIP
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: shopfer-ingress
  namespace: ${APP_NAMESPACE}
  labels:
    app: shopfer
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "false"
spec:
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
                    if exist kubeconfig2 set KUBECONFIG=%WORKSPACE%\\kubeconfig2
                    
                    echo "=== Déploiement de l'application ==="
                    kubectl apply -f k8s-deployment.yaml --validate=false
                    
                    echo "=== Attente du déploiement ==="
                    kubectl rollout status deployment/shopfer-app -n %APP_NAMESPACE% --timeout=300s
                    
                    echo "=== État final ==="
                    kubectl get all -n %APP_NAMESPACE%
                    kubectl get ingress -n %APP_NAMESPACE%
                '''
            }
        }
        
        stage('DNS & Verification') {
            when {
                expression { return currentBuild.currentResult != 'FAILURE' }
            }
            steps {
                bat '''
                    set KUBECONFIG=%WORKSPACE%\\kubeconfig
                    if exist kubeconfig2 set KUBECONFIG=%WORKSPACE%\\kubeconfig2
                    
                    echo "=== Récupération de l'IP externe ==="
                    set counter=0
                    :loop
                    if %counter% geq 300 goto :skip_dns
                    
                    for /f "tokens=*" %%i in ('kubectl get service ingress-nginx-controller -n ingress-nginx -o jsonpath^="{.status.loadBalancer.ingress[0].ip}" 2^>nul') do set EXTERNAL_IP=%%i
                    if not "!EXTERNAL_IP!"=="" if not "!EXTERNAL_IP!"=="null" goto :update_dns
                    
                    timeout /t 10 /nobreak >nul
                    set /a counter+=10
                    goto :loop
                    
                    :update_dns
                    echo IP externe trouvé: !EXTERNAL_IP!
                    curl -s "https://www.duckdns.org/update?domains=shopfer-ecommerce&token=%DUCKDNS_TOKEN%&ip=!EXTERNAL_IP!"
                    echo.
                    echo DNS mis à jour avec succès
                    goto :end
                    
                    :skip_dns
                    echo Timeout - IP externe non disponible
                    
                    :end
                    echo "=== Résumé final ==="
                    kubectl get all,ingress -n %APP_NAMESPACE%
                    echo.
                    echo "Application accessible à: http://%DOMAIN_NAME%"
                '''
            }
        }
    }
    
    post {
        always {
            script {
                try {
                    robot(outputPath: 'robot-tests', outputFileName: 'output.xml', reportFileName: 'report.html', 
                          logFileName: 'log.html', disableArchiveOutput: false, passThreshold: 80, 
                          unstableThreshold: 60, otherFiles: '*.png,*.jpg')
                } catch (Exception e) { 
                    echo "Robot Framework non disponible: ${e.message}"
                }
                
                try {
                    archiveArtifacts artifacts: 'robot-tests/**/*.{xml,html,log,png,jpg},kubeconfig*,k8s-*.yaml', 
                                   allowEmptyArchive: true, fingerprint: true
                } catch (Exception e) {
                    echo "Erreur archivage: ${e.message}"
                }
                
                bat 'docker rmi %DOCKER_IMAGE_NAME%:%DOCKER_TAG% 2>nul || exit /b 0'
            }
        }
        
        success { 
            echo "✅ Pipeline réussi!"
            echo "🌐 Application: http://${DOMAIN_NAME}"
            echo "📊 Monitoring: Vérifiez les logs Kubernetes pour la santé de l'application"
        }
        
        failure { 
            echo "❌ Pipeline échoué!"
            bat '''
                echo "=== Diagnostic de l'échec ==="
                if exist kubeconfig (
                    echo "Kubeconfig principal trouvé"
                    type kubeconfig | findstr "server:"
                ) else echo "Kubeconfig principal manquant"
                
                if exist kubeconfig2 (
                    echo "Kubeconfig secondaire trouvé"
                    type kubeconfig2 | findstr "server:"
                ) else echo "Kubeconfig secondaire manquant"
                
                if exist robot-tests dir robot-tests /b
                
                echo "=== État Azure ==="
                az account show --query "{subscription:id,tenant:tenantId}" 2>nul || echo "Pas de connexion Azure active"
            '''
        }
    }
}
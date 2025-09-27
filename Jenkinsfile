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
        
        stage('Build & Test') {
            steps {
                bat '''
                    call npm install && call npm run build --prod
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
        
        stage('Cleanup & Docker Build') {
            steps {
                bat '''
                    for /f "tokens=5" %%a in ('netstat -aon 2^>nul ^| find ":4200" ^| find "LISTENING"') do taskkill /f /pid %%a 2>nul
                    taskkill /f /im node.exe /im npm.cmd 2>nul || exit /b 0
                '''
                
                script {
                    bat '''
                        docker build -t %DOCKER_IMAGE_NAME%:%DOCKER_TAG% .
                        docker tag %DOCKER_IMAGE_NAME%:%DOCKER_TAG% %DOCKER_IMAGE_NAME%:latest
                    '''
                    
                    withCredentials([usernamePassword(credentialsId: 'docker-hub-login', usernameVariable: 'DOCKER_HUB_USER', passwordVariable: 'DOCKER_HUB_PASS')]) {
                        bat '''
                            docker login -u %DOCKER_HUB_USER% -p %DOCKER_HUB_PASS%
                            docker push %DOCKER_IMAGE_NAME%:%DOCKER_TAG% && docker push %DOCKER_IMAGE_NAME%:latest
                        '''
                    }
                }
            }
        }
        
        stage('AKS Connection & Setup') {
            steps {
                withCredentials([azureServicePrincipal(credentialsId: 'azure-service-principal', 
                    subscriptionIdVariable: 'ARM_SUBSCRIPTION_ID', clientIdVariable: 'ARM_CLIENT_ID',
                    clientSecretVariable: 'ARM_CLIENT_SECRET', tenantIdVariable: 'ARM_TENANT_ID')]) {
                    
                    bat '''
                        echo "Connexion à Azure avec Service Principal..."
                        az login --service-principal --username %ARM_CLIENT_ID% --password="%ARM_CLIENT_SECRET%" --tenant %ARM_TENANT_ID%
                        echo "Configuration de la subscription..."
                        az account set --subscription %ARM_SUBSCRIPTION_ID%
                        echo "Vérification des credentials AKS..."
                        az aks list --resource-group %RESOURCE_GROUP_NAME% --output table
                        echo "Récupération des credentials AKS avec admin access..."
                        az aks get-credentials --resource-group %RESOURCE_GROUP_NAME% --name %CLUSTER_NAME% --file kubeconfig --overwrite-existing --admin
                        echo "Vérification du fichier kubeconfig créé..."
                        if exist kubeconfig (echo Kubeconfig créé avec succès) else (echo ERREUR: Kubeconfig non créé && exit /b 1)
                    '''
                }
                
                bat '''
                    set KUBECONFIG=%WORKSPACE%\\kubeconfig
                    echo "=== Vérifications kubectl ==="
                    echo "Test de connexion kubectl..."
                    kubectl version --client
                    kubectl cluster-info
                    echo "Vérification des noeuds..."
                    kubectl get nodes
                    
                    echo "=== Configuration namespace ==="
                    kubectl create namespace %APP_NAMESPACE% --dry-run=client -o yaml | kubectl apply -f -
                    kubectl get namespace %APP_NAMESPACE%
                    
                    echo "=== Installation NGINX Ingress Controller ==="
                    kubectl get namespace ingress-nginx 2>nul || (
                        echo "Installation du contrôleur ingress..."
                        kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml --validate=false
                    )
                    
                    echo "Attente du déploiement de l'Ingress Controller..."
                    kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=600s --ignore-not-found=true
                    
                    echo "=== Vérification de l'état de l'ingress ==="
                    kubectl get pods -n ingress-nginx
                    kubectl get svc -n ingress-nginx
                '''
            }
        }
        
        stage('Deploy Application') {
            steps {
                bat '''
                    set KUBECONFIG=%WORKSPACE%\\kubeconfig
                    kubectl delete ingress,deployment,service -l app=shopfer -n %APP_NAMESPACE% --ignore-not-found=true
                    timeout /t 10 /nobreak >nul
                '''
                
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
            memory: "512Mi"
            cpu: "500m"
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
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "3600"
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
                    kubectl rollout status deployment/shopfer-app -n %APP_NAMESPACE% --timeout=600s
                    kubectl get pods -n %APP_NAMESPACE%
                '''
            }
        }
        
        stage('DNS & Verification') {
            steps {
                bat '''
                    set KUBECONFIG=%WORKSPACE%\\kubeconfig
                    
                    set counter=0
                    set timeout=600
                    set externalIP=
                    
                    :loop
                    if %counter% geq %timeout% goto :end
                    for /f "tokens=*" %%i in ('kubectl get service ingress-nginx-controller -n ingress-nginx -o jsonpath^="{.status.loadBalancer.ingress[0].ip}" 2^>nul') do set externalIP=%%i
                    if not "%externalIP%"=="" if not "%externalIP%"=="null" goto :update_dns
                    timeout /t 10 /nobreak >nul
                    set /a counter+=10
                    goto :loop
                    
                    :update_dns
                    curl "https://www.duckdns.org/update?domains=shopfer-ecommerce&token=%DUCKDNS_TOKEN%&ip=%externalIP%"
                    echo IP externe obtenu: %externalIP%
                    
                    :end
                    kubectl get all,ingress -n %APP_NAMESPACE%
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
                    archiveArtifacts artifacts: 'robot-tests/**/*.{xml,html,log,png,jpg},kubeconfig,k8s-all.yaml', 
                                   allowEmptyArchive: true, fingerprint: true
                } catch (Exception e) { 
                    echo "Erreur lors de l'archivage: ${e.message}"
                }
                
                bat 'docker rmi %DOCKER_IMAGE_NAME%:%DOCKER_TAG% 2>nul || exit /b 0'
            }
        }
        
        success { echo "✅ Pipeline réussi! App: http://${DOMAIN_NAME}" }
        failure { 
            echo "❌ Pipeline échoué! Vérifiez: Azure credentials, Docker Hub, DuckDNS token"
            bat '''
                if exist robot-tests dir robot-tests
                if exist kubeconfig (
                    echo "=== Contenu du kubeconfig Jenkins ==="
                    type kubeconfig | findstr "server:"
                    echo "=== Test kubectl avec le kubeconfig Jenkins ==="
                    set KUBECONFIG=%WORKSPACE%\\kubeconfig
                    kubectl config view --minify
                    kubectl auth can-i get pods --all-namespaces 2>nul || echo "Pas d'autorisation kubectl"
                ) else (
                    echo "ERREUR: Fichier kubeconfig non trouvé"
                )
                echo "=== Logs de débogage Azure ==="
                az account show 2>nul || echo "Pas de connexion Azure"
                az aks show --resource-group %RESOURCE_GROUP_NAME% --name %CLUSTER_NAME% --query "powerState" 2>nul || echo "Impossible de vérifier l'état AKS"
            '''
        }
    }
}
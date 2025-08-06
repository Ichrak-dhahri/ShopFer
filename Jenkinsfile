pipeline {
    agent any
    
    environment {
        DOCKER_HUB_REGISTRY = 'docker.io'
        DOCKER_IMAGE_NAME = 'farahabbes/shopferimgg'
        DOCKER_TAG = "${BUILD_NUMBER}"
        
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
                bat '''
                    start "Angular App" /min cmd /c "npm run start"
                '''
                
                script {
                    def maxAttempts = 30
                    def attempt = 0
                    def appStarted = false
                    
                    while (attempt < maxAttempts && !appStarted) {
                        try {
                            sleep(2)
                            bat 'netstat -an | find "4200" | find "LISTENING"'
                            appStarted = true
                        } catch (Exception e) {
                            attempt++
                        }
                    }
                    
                    if (!appStarted) {
                        error("Application Angular n'a pas démarré")
                    }
                }
            }
        }
        
        stage('Setup Robot Framework Environment') {
            steps {
                bat '''
                    if not exist robot-tests mkdir robot-tests
                    cd robot-tests
                    if exist robot_env rmdir /s /q robot_env
                    python -m venv robot_env
                    robot_env\\Scripts\\python.exe -m pip install --upgrade pip
                    robot_env\\Scripts\\pip install robotframework robotframework-seleniumlibrary selenium webdriver-manager
                '''
            }
        }
        
        stage('Verify Application Status') {
            steps {
                bat '''
                    tasklist | find "node.exe" || echo No Node process
                    netstat -an | find "4200" || echo Port 4200 not found
                    curl -f http://localhost:4200 || echo Connection failed
                '''
            }
        }
        
        stage('Run Robot Framework tests') {
            steps {
                bat '''
                    cd robot-tests
                    robot_env\\Scripts\\robot --outputdir . ^
                                              --variable BROWSER:headlesschrome ^
                                              --variable URL:http://localhost:4200 ^
                                              --loglevel INFO ^
                                              hello.robot
                '''
            }
        }
        
        stage('Stop Angular Application') {
            steps {
                bat '''
                    for /f "tokens=5" %%a in ('netstat -aon 2^>nul ^| find ":4200" ^| find "LISTENING"') do taskkill /f /pid %%a 2>nul
                    taskkill /f /im node.exe 2>nul
                    taskkill /f /im npm.cmd 2>nul
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
        
        stage('Setup K8s & NGINX') {
            steps {
                bat '''
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
                    kubectl delete ingress,deployment,service -l app=shopfer -n $env:APP_NAMESPACE --ignore-not-found=true
                    Start-Sleep 10
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
                    kubectl apply -f k8s-all.yaml
                    kubectl rollout status deployment/shopfer-app -n %APP_NAMESPACE% --timeout=300s
                '''
            }
        }
        
        stage('Configure DNS') {
            steps {
                powershell '''
                    $timeout = 600; $counter = 0; $externalIP = $null
                    do {
                        if ($counter -ge $timeout) { break }
                        $externalIP = kubectl get service ingress-nginx-controller -n ingress-nginx -o jsonpath="{.status.loadBalancer.ingress[0].ip}" 2>$null
                        if ($externalIP -and $externalIP -ne "null" -and $externalIP -ne "") {
                            break
                        }
                        Start-Sleep 10; $counter += 10
                    } while ($true)
                    
                    if ($externalIP) {
                        $uri = "https://www.duckdns.org/update?domains=shopfer-ecommerce&token=$env:DUCKDNS_TOKEN&ip=$externalIP"
                        Invoke-RestMethod -Uri $uri
                    }
                '''
            }
        }
        
        stage('Verify') {
            steps {
                bat '''
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
                } catch (Exception e) {
                    // Robot results publication failed
                }
                
                try {
                    archiveArtifacts artifacts: 'robot-tests/**/*.{xml,html,log,png,jpg},k8s-all.yaml', allowEmptyArchive: true, fingerprint: true
                } catch (Exception e) {
                    // Archive failed
                }
                
                bat 'docker rmi %DOCKER_IMAGE_NAME%:%DOCKER_TAG% 2>nul || echo "Cleanup done"'
            }
        }
        
        success {
            echo "✅ Pipeline successful! App: http://${DOMAIN_NAME}"
        }
        
        failure {
            echo "❌ Pipeline failed! Check: Docker Hub, DuckDNS token"
            bat '''
                tasklist | find "node.exe" || echo No Node process
                netstat -an | find "4200" || echo Port 4200 not found
                if exist robot-tests dir robot-tests
            '''
        }
    }
}
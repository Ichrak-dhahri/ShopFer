pipeline {
    agent any

    stages {
        stage('Clone repository') {
            steps {
                git branch: 'main', url: 'https://github.com/Ichrak-dhahri/ShopFer.git'
            }
        }

        stage('Install dependencies') {
            steps {
                bat 'call npm install'
            }
        }

        stage('Run unit tests') {
            steps {
                bat 'call npm run test -- --karma-config karma.conf.js --watch=false --code-coverage'
            }
        }

        stage('Build Angular Application') {
            steps {
                bat 'call npm run build'
            }
        }

        stage('Build Docker Image') {
            steps {
                bat 'docker build -t farahabbes/shopferimgg .'
            }
        }

        stage('Push Docker Image to Docker Hub') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'docker-hub-login', usernameVariable: 'DOCKER_HUB_USER', passwordVariable: 'DOCKER_HUB_PASS')]) {
                    bat """
                        docker tag farahabbes/shopferimgg %DOCKER_HUB_USER%/shopferimgg:latest
                        docker login -u %DOCKER_HUB_USER% -p %DOCKER_HUB_PASS%
                        docker push %DOCKER_HUB_USER%/shopferimgg:latest
                    """
                }
            }
        }

        stage('Pre-deployment Cleanup') {
            steps {
                script {
                    try {
                        bat '''
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

        stage('Run Docker Container') {
            steps {
                bat 'docker run -d --name shopfer-container -p 4200:4200 farahabbes/shopferimgg'

                // Verify container started
                script {
                    sleep(5)
                    def containerStatus = bat(script: 'docker ps --filter "name=shopfer-container" --format "{{.Status}}"', returnStdout: true).trim()
                    if (!containerStatus.contains("Up")) {
                        error("Container failed to start properly")
                    }
                    echo "Container started successfully: ${containerStatus}"
                }
            }
        }

        stage('Verify Application Status') {
            steps {
                script {
                    def maxAttempts = 30
                    def attempt = 0
                    def appStarted = false

                    while (attempt < maxAttempts && !appStarted) {
                        try {
                            sleep(2)
                            bat 'netstat -an | find "4200" | find "LISTENING"'
                            appStarted = true
                            echo "Application is listening on port 4200"
                        } catch (Exception e) {
                            attempt++
                            if (attempt % 10 == 0) {
                                echo "Waiting for application... (${attempt}/${maxAttempts})"
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
                        error("Application failed to start within timeout")
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
                    robot_env\\Scripts\\python.exe -m pip install --upgrade pip --quiet
                    robot_env\\Scripts\\pip install robotframework robotframework-seleniumlibrary selenium webdriver-manager --quiet
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
            environment {
                TF_VAR_resource_group_name = 'rg-shopfer-aks'
                TF_VAR_cluster_name = 'aks-shopfer'
                TF_VAR_location = 'francecentral'
                TF_VAR_node_count = '1'
                TF_VAR_kubernetes_version = '1.30.14'
                TF_VAR_vm_size = 'Standard_B2s'
            }
            steps {
                withCredentials([azureServicePrincipal(credentialsId: 'azure-service-principal', 
                    subscriptionIdVariable: 'ARM_SUBSCRIPTION_ID',
                    clientIdVariable: 'ARM_CLIENT_ID',
                    clientSecretVariable: 'ARM_CLIENT_SECRET',
                    tenantIdVariable: 'ARM_TENANT_ID')]) {
                    
                    script {
                        bat '''
                            cd terraform-aks
                            
                            echo "🔐 Configuration des variables d'environnement Azure..."
                            echo "Subscription ID: %ARM_SUBSCRIPTION_ID%"
                            echo "Client ID: %ARM_CLIENT_ID%"
                            echo "Tenant ID: %ARM_TENANT_ID%"
                            
                            echo "🔑 Azure CLI Login..."
                            az login --service-principal -u %ARM_CLIENT_ID% -p %ARM_CLIENT_SECRET% --tenant %ARM_TENANT_ID%
                            az account set --subscription %ARM_SUBSCRIPTION_ID%
                            
                            echo "🏗️ Initialisation de Terraform..."
                            terraform init
                            
                            echo "🔍 Validation de la configuration Terraform..."
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
                                    echo "📦 Import du Resource Group existant..."
                                    terraform import azurerm_resource_group.aks_rg "/subscriptions/%ARM_SUBSCRIPTION_ID%/resourceGroups/%TF_VAR_resource_group_name%" || echo "Resource Group import failed, continuing..."
                                )
                                
                                REM Import AKS Cluster if exists  
                                az aks show --name %TF_VAR_cluster_name% --resource-group %TF_VAR_resource_group_name% --subscription %ARM_SUBSCRIPTION_ID% >nul 2>&1
                                if %ERRORLEVEL% EQU 0 (
                                    echo "☸️ Import du cluster AKS existant..."
                                    terraform import azurerm_kubernetes_cluster.aks "/subscriptions/%ARM_SUBSCRIPTION_ID%/resourceGroups/%TF_VAR_resource_group_name%/providers/Microsoft.ContainerService/managedClusters/%TF_VAR_cluster_name%" || echo "AKS import failed, continuing..."
                                )
                            '''
                        } catch (Exception e) {
                            echo "Import phase completed with warnings: ${e.getMessage()}"
                        }
                        
                        // Plan and Apply
                        bat '''
                            cd terraform-aks
                            echo "📋 Planning infrastructure changes..."
                            terraform plan -out=tfplan
                            
                            echo "🚀 Applying infrastructure changes..."
                            terraform apply -auto-approve tfplan
                            
                            echo "✅ Vérification des outputs..."
                            terraform output
                            
                            echo "💾 Récupération de la config Kubernetes..."
                            terraform output -raw kube_config > ../kubeconfig 2>nul || (
                                echo "⚠️ Kube config not available from Terraform output"
                                echo "🔄 Récupération via Azure CLI..."
                                az aks get-credentials --resource-group %TF_VAR_resource_group_name% --name %TF_VAR_cluster_name% --file ../kubeconfig --overwrite-existing
                            )
                        '''
                    }
                }
            }
        }

        stage('Deploy to AKS') {
            environment {
                RESOURCE_GROUP = 'rg-shopfer-aks'
                CLUSTER_NAME = 'aks-shopfer'
                ACR_NAME = 'shopfer'
                APP_NAMESPACE = 'shopfer-app'
                DOMAIN_NAME = 'shopfer-ecommerce.duckdns.org'
            }

            steps {
                withCredentials([azureServicePrincipal(credentialsId: 'azure-service-principal', 
                    subscriptionIdVariable: 'ARM_SUBSCRIPTION_ID',
                    clientIdVariable: 'ARM_CLIENT_ID',
                    clientSecretVariable: 'ARM_CLIENT_SECRET',
                    tenantIdVariable: 'ARM_TENANT_ID')]) {
                    script {
                        try {
                            // Azure Login
                            bat """
                            az login --service-principal -u %ARM_CLIENT_ID% -p %ARM_CLIENT_SECRET% --tenant %ARM_TENANT_ID%
                            """

                            // Get AKS Credentials
                            bat """
                            az aks get-credentials --resource-group ${RESOURCE_GROUP} --name ${CLUSTER_NAME} --overwrite-existing
                            """

                            // Test kubectl connectivity
                            bat 'kubectl cluster-info'

                            // Create namespace
                            bat """
                            kubectl create namespace ${APP_NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
                            """

                            // Install NGINX Ingress Controller
                            bat '''
                            kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml
                            kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=300s
                            '''

                            // Clean existing resources
                            bat """
                            kubectl delete ingress shopfer-ingress -n ${APP_NAMESPACE} --ignore-not-found=true
                            kubectl delete deployment shopfer-app -n ${APP_NAMESPACE} --ignore-not-found=true  
                            kubectl delete service shopfer-service -n ${APP_NAMESPACE} --ignore-not-found=true
                            """

                            // Create Kubernetes manifests
                            writeFile file: 'deployment.yaml', text: """
apiVersion: apps/v1
kind: Deployment
metadata:
  name: shopfer-app
  namespace: ${APP_NAMESPACE}
  labels:
    app: shopfer
spec:
  replicas: 1
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
        image: farahabbes/shopferimgg:latest
        ports:
        - containerPort: 4200
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
"""

                            writeFile file: 'service.yaml', text: """
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

                            writeFile file: 'ingress.yaml', text: """
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

                            // Apply Kubernetes manifests
                            bat 'kubectl apply -f service.yaml'
                            bat 'kubectl apply -f deployment.yaml'
                            bat 'kubectl apply -f ingress.yaml'
                            bat "kubectl rollout restart deployment shopfer-app -n ${APP_NAMESPACE}"

                            // Wait for deployment to complete
                            bat "kubectl rollout status deployment/shopfer-app -n ${APP_NAMESPACE} --timeout=300s"

                            // Get pod status
                            bat "kubectl get pods -n ${APP_NAMESPACE} -o wide"

                        } catch (Exception e) {
                            echo "⚠️ AKS deployment failed: ${e.getMessage()}"

                            // Diagnostic on failure
                            try {
                                bat "kubectl get pods -n ${APP_NAMESPACE} -o wide || echo \"No pods found\""
                                bat "kubectl describe deployment shopfer-app -n ${APP_NAMESPACE} || echo \"No deployment found\""
                                bat 'kubectl get events --sort-by=.metadata.creationTimestamp | tail -10 || echo "No events"'
                            } catch (Exception diagnosticError) {
                                echo "⚠️ Could not retrieve diagnostics: ${diagnosticError.getMessage()}"
                            }

                            throw e // Re-throw to mark pipeline as failed
                        }
                    }
                }
            }
        }

        stage('Get LoadBalancer IP & Configure DNS') {
            steps {
                withCredentials([string(credentialsId: 'duckdns-token', variable: 'DUCKDNS_TOKEN')]) {
                    powershell '''
                        Write-Host "🌍 Récupération de l'IP du LoadBalancer..." -ForegroundColor Green
                        
                        $timeout = 600
                        $counter = 0
                        $externalIP = $null
                        
                        do {
                            if ($counter -ge $timeout) {
                                Write-Host "⚠️ Timeout atteint pour l'obtention de l'IP externe" -ForegroundColor Yellow
                                break
                            }
                            
                            $externalIP = kubectl get service ingress-nginx-controller -n ingress-nginx -o jsonpath="{.status.loadBalancer.ingress[0].ip}" 2>$null
                            
                            if ($externalIP -and $externalIP -ne "null" -and $externalIP -ne "") {
                                Write-Host "✅ IP externe obtenue: $externalIP" -ForegroundColor Green
                                $externalIP | Out-File -FilePath "external_ip.txt" -Encoding ASCII
                                
                                # Configure DNS
                                Write-Host "🌐 Configuration DNS DuckDNS..." -ForegroundColor Green
                                $uri = "https://www.duckdns.org/update?domains=shopfer-ecommerce&token=$env:DUCKDNS_TOKEN&ip=$externalIP"
                                Invoke-RestMethod -Uri $uri
                                break
                            }
                            
                            Start-Sleep -Seconds 10
                            $counter += 10
                            Write-Host "Attente de l'IP externe... ($counter/$timeout seconds)" -ForegroundColor Yellow
                        } while ($true)
                    '''
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
                    if (fileExists('robot-tests')) {
                        archiveArtifacts artifacts: 'robot-tests/**/*.{xml,html,log,png,jpg}', allowEmptyArchive: true, fingerprint: true
                    }
                    if (fileExists('terraform-aks')) {
                        archiveArtifacts artifacts: 'terraform-aks/tfplan,kubeconfig,external_ip.txt,*.yaml', allowEmptyArchive: true, fingerprint: true
                    }
                } catch (Exception e) {
                    echo "Warning: Could not archive artifacts"
                }
            }
        }

        success {
            script {
                echo 'Pipeline completed successfully ✅'
                
                if (fileExists('external_ip.txt')) {
                    def externalIP = readFile('external_ip.txt').trim()
                    echo """
                    🎉 Déploiement réussi !
                    
                    📍 URLs d'accès:
                    - Application locale: http://localhost:4200
                    - Application AKS: http://shopfer-ecommerce.duckdns.org
                    - IP LoadBalancer: ${externalIP}
                    """
                } else {
                    echo 'Application is running at http://localhost:4200'
                }

                try {
                    bat '''
                        echo === SUCCESS SUMMARY ===
                        docker ps --filter "name=shopfer-container" --format "table {{.Names}}\\t{{.Status}}\\t{{.Ports}}"
                        kubectl get pods -n shopfer-app -o wide 2>nul || echo "AKS deployment status unknown"
                    '''
                } catch (Exception e) {
                    echo "Could not display success summary"
                }
            }
        }

        failure {
            echo 'Pipeline failed ❌'

            script {
                try {
                    bat '''
                        echo === FAILURE DIAGNOSTIC ===
                        echo "Docker containers:"
                        docker ps -a --filter "name=shopfer" --format "table {{.Names}}\\t{{.Status}}\\t{{.Ports}}" 2>nul || echo "No shopfer containers"

                        echo "Port 4200 status:"
                        netstat -an | find "4200" 2>nul || echo "Port 4200 not in use"

                        echo "Container logs (last 20 lines):"
                        docker logs --tail 20 shopfer-container 2>nul || echo "No container logs available"

                        echo "Robot test results:"
                        if exist robot-tests\\output.xml echo "Robot test results available" else echo "No robot test results"

                        echo "AKS status:"
                        kubectl get pods -n shopfer-app 2>nul || echo "Cannot connect to AKS or no shopfer pods"
                    '''
                } catch (Exception e) {
                    echo "Diagnostic failed but continuing..."
                }

                // Only cleanup on failure
                try {
                    bat '''
                        echo "Cleaning up failed containers..."
                        docker stop shopfer-container 2>nul || echo "Container already stopped"
                        docker rm shopfer-container 2>nul || echo "Container already removed"
                        for /f "tokens=5" %%a in ('netstat -aon 2^>nul ^| find ":4200" ^| find "LISTENING"') do (
                            taskkill /f /pid %%a 2^>nul || echo "Process cleanup"
                        )
                    '''
                } catch (Exception e) {
                    echo "Cleanup completed with warnings"
                }
            }
        }
    }
}
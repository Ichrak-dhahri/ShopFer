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
                bat 'docker build -t shopferimgg .'
            }
        }

        stage('Push Docker Image to Docker Hub') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'docker-hub-login', usernameVariable: 'DOCKER_HUB_USER', passwordVariable: 'DOCKER_HUB_PASS')]) {
                    bat """
                        docker tag shopferimgg %DOCKER_HUB_USER%/shopferimgg:latest
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
                bat 'docker run -d --name shopfer-container -p 4200:4200 shopferimgg'

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

        stage('Deploy to AKS') {
            environment {
                RESOURCE_GROUP = 'shopfer'
                CLUSTER_NAME = 'shopfer'
                TENANT_ID = 'dbd6664d-4eb9-46eb-99d8-5c43ba153c61'
                ACR_NAME = 'shopfer'
            }

            steps {
                withCredentials([usernamePassword(credentialsId: 'azure-sp', usernameVariable: 'AZURE_CLIENT_ID', passwordVariable: 'AZURE_CLIENT_SECRET')]) {
                    script {
                        try {
                            // Azure Login
                            bat """
                            az login --service-principal -u ${AZURE_CLIENT_ID} -p ${AZURE_CLIENT_SECRET} --tenant ${TENANT_ID}
                            """

                            // Get AKS Credentials
                            bat """
                            az aks get-credentials --resource-group ${RESOURCE_GROUP} --name ${CLUSTER_NAME} --overwrite-existing
                            """

                            // Test kubectl connectivity
                            bat 'kubectl cluster-info'

                            // Apply Kubernetes manifests
                            bat 'kubectl apply -f service.yaml'
                            bat 'kubectl apply -f configmap.yaml'
                            bat 'kubectl apply -f deployment.yaml'
                            bat "kubectl rollout restart deployment shopfer-app"

                            // Wait for deployment to complete
                            bat 'kubectl rollout status deployment/shopfer-app --timeout=300s'

                            // Get pod status
                            bat 'kubectl get pods -l app=shopfer -o wide'

                        } catch (Exception e) {
                            echo "⚠️ AKS deployment failed: ${e.getMessage()}"

                            // Diagnostic on failure
                            try {
                                bat 'kubectl get pods -l app=shopfer -o wide || echo "No pods found"'
                                bat 'kubectl describe deployment shopfer || echo "No deployment found"'
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
                } catch (Exception e) {
                    echo "Warning: Could not archive artifacts"
                }
            }
        }

        success {
            echo 'Pipeline completed successfully ✅'
            echo 'Application is running at http://localhost:4200'

            script {
                try {
                    bat '''
                        echo === SUCCESS SUMMARY ===
                        docker ps --filter "name=shopfer-container" --format "table {{.Names}}\\t{{.Status}}\\t{{.Ports}}"
                        kubectl get pods -l app=shopfer -o wide 2>nul || echo "AKS deployment status unknown"
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
                        kubectl get pods -l app=shopfer 2>nul || echo "Cannot connect to AKS or no shopfer pods"
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

pipeline {
    agent any
    
    environment {
        scannerHome = tool 'Sonar'
        DOCKER_IMAGE_NAME = 'shopferimgg'
        DOCKER_CONTAINER_NAME = 'shopfer-container'
        APP_PORT = '4200'
    }
    
    stages {
        stage('Clone repository') {
            steps {
                git branch: 'main', url: 'https://github.com/Ichrak-dhahri/ShopFer.git'
            }
        }

        stage('Install dependencies') {
            steps {
                script {
                    if (isUnix()) {
                        sh 'npm install'
                    } else {
                        bat 'npm install'
                    }
                }
            }
        }

        stage('Run unit tests') {
            steps {
                script {
                    if (isUnix()) {
                        sh 'npm run test -- --karma-config karma.conf.js --watch=false --code-coverage --browsers=ChromeHeadless'
                    } else {
                        bat 'npm run test -- --karma-config karma.conf.js --watch=false --code-coverage --browsers=ChromeHeadless'
                    }
                }
            }
        }

        stage('Build Angular Application') {
            steps {
                script {
                    if (isUnix()) {
                        sh 'npm run build'
                    } else {
                        bat 'npm run build'
                    }
                }
            }
        }

        stage('Start Application for Testing') {
            steps {
                script {
                    // Start the application in background
                    if (isUnix()) {
                        sh 'nohup npm start > app.log 2>&1 &'
                    } else {
                        bat 'start /B npm start'
                    }
                    
                    // Wait for application to start
                    def maxAttempts = 30
                    def attempt = 0
                    def appStarted = false

                    while (attempt < maxAttempts && !appStarted) {
                        try {
                            sleep(3)
                            if (isUnix()) {
                                sh 'curl -f http://localhost:4200 || exit 1'
                            } else {
                                bat 'powershell -Command "Invoke-WebRequest -Uri http://localhost:4200 -UseBasicParsing"'
                            }
                            appStarted = true
                            echo "Application started successfully!"
                        } catch (Exception e) {
                            attempt++
                            if (attempt % 5 == 0) {
                                echo "Waiting for application... (${attempt}/${maxAttempts})"
                            }
                        }
                    }

                    if (!appStarted) {
                        error("Application failed to start within timeout")
                    }
                }
            }
        }

        stage('Setup Robot Framework Environment') {
            steps {
                script {
                    if (isUnix()) {
                        sh '''
                            mkdir -p robot-tests
                            cd robot-tests
                            rm -rf robot_env
                            python3 -m venv robot_env
                            source robot_env/bin/activate
                            pip install --upgrade pip
                            pip install robotframework robotframework-seleniumlibrary selenium webdriver-manager
                        '''
                    } else {
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
            }
        }

        stage('Create Robot Test File') {
            steps {
                script {
                    // Create a basic robot test file if it doesn't exist
                    def robotTestContent = '''*** Settings ***
Library    SeleniumLibrary

*** Variables ***
\${URL}    http://localhost:4200
\${BROWSER}    headlesschrome

*** Test Cases ***
Open Application
    Open Browser    \${URL}    \${BROWSER}
    Title Should Contain    ShopFer
    Close Browser

Basic Page Load Test
    Open Browser    \${URL}    \${BROWSER}
    Wait Until Page Contains Element    tag:body    timeout=10s
    Page Should Not Contain    Error
    Close Browser
'''
                    writeFile file: 'robot-tests/hello.robot', text: robotTestContent
                }
            }
        }

        stage('Run Robot Framework tests') {
            steps {
                script {
                    if (isUnix()) {
                        sh '''
                            cd robot-tests
                            source robot_env/bin/activate
                            robot --outputdir . \\
                                  --variable BROWSER:headlesschrome \\
                                  --variable URL:http://localhost:4200 \\
                                  --loglevel INFO \\
                                  hello.robot
                        '''
                    } else {
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
            }
        }

        stage('Run SonarQube Analysis') {
            when {
                expression { return env.scannerHome != null }
            }
            steps {
                withSonarQubeEnv(credentialsId: 'SQube-token', installationName: 'SonarQube') {
                    script {
                        if (isUnix()) {
                            sh "${scannerHome}/bin/sonar-scanner"
                        } else {
                            bat "${scannerHome}\\bin\\sonar-scanner.bat"
                        }
                    }
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    // Ensure Dockerfile exists
                    if (!fileExists('Dockerfile')) {
                        def dockerfileContent = '''FROM node:16-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY dist/ ./dist/

EXPOSE 4200

CMD ["npx", "http-server", "dist", "-p", "4200"]
'''
                        writeFile file: 'Dockerfile', text: dockerfileContent
                    }
                    
                    if (isUnix()) {
                        sh "docker build -t ${DOCKER_IMAGE_NAME} ."
                    } else {
                        bat "docker build -t ${DOCKER_IMAGE_NAME} ."
                    }
                }
            }
        }

        stage('Push Docker Image to Docker Hub') {
            when {
                expression { return env.DOCKER_HUB_USER != null }
            }
            steps {
                withCredentials([usernamePassword(credentialsId: 'docker-hub-login', usernameVariable: 'DOCKER_HUB_USER', passwordVariable: 'DOCKER_HUB_PASS')]) {
                    script {
                        if (isUnix()) {
                            sh """
                                docker tag ${DOCKER_IMAGE_NAME} \${DOCKER_HUB_USER}/${DOCKER_IMAGE_NAME}:latest
                                echo \${DOCKER_HUB_PASS} | docker login -u \${DOCKER_HUB_USER} --password-stdin
                                docker push \${DOCKER_HUB_USER}/${DOCKER_IMAGE_NAME}:latest
                            """
                        } else {
                            bat """
                                docker tag ${DOCKER_IMAGE_NAME} %DOCKER_HUB_USER%/${DOCKER_IMAGE_NAME}:latest
                                docker login -u %DOCKER_HUB_USER% -p %DOCKER_HUB_PASS%
                                docker push %DOCKER_HUB_USER%/${DOCKER_IMAGE_NAME}:latest
                            """
                        }
                    }
                }
            }
        }

        stage('Deploy Docker Container') {
            steps {
                script {
                    // Stop and remove existing container
                    try {
                        if (isUnix()) {
                            sh """
                                docker stop ${DOCKER_CONTAINER_NAME} || true
                                docker rm ${DOCKER_CONTAINER_NAME} || true
                            """
                        } else {
                            bat """
                                docker stop ${DOCKER_CONTAINER_NAME} 2>nul || echo Container not running
                                docker rm ${DOCKER_CONTAINER_NAME} 2>nul || echo Container not found
                            """
                        }
                    } catch (Exception e) {
                        echo "Container cleanup completed"
                    }

                    // Run new container
                    if (isUnix()) {
                        sh "docker run -d --name ${DOCKER_CONTAINER_NAME} -p ${APP_PORT}:${APP_PORT} ${DOCKER_IMAGE_NAME}"
                    } else {
                        bat "docker run -d --name ${DOCKER_CONTAINER_NAME} -p ${APP_PORT}:${APP_PORT} ${DOCKER_IMAGE_NAME}"
                    }
                }
            }
        }
    }

    post {
        always {
            script {
                // Stop application processes
                try {
                    if (isUnix()) {
                        sh '''
                            pkill -f "npm start" || true
                            pkill -f "ng serve" || true
                        '''
                    } else {
                        bat '''
                            for /f "tokens=5" %%a in ('netstat -aon 2^>nul ^| find ":4200" ^| find "LISTENING"') do (
                                taskkill /f /pid %%a 2^>nul || echo Process already stopped
                            )
                        '''
                    }
                } catch (Exception e) {
                    echo "Process cleanup completed"
                }

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
                    echo "Warning: Could not publish Robot Framework results: ${e.getMessage()}"
                }

                // Archive artifacts
                try {
                    if (fileExists('robot-tests')) {
                        archiveArtifacts artifacts: 'robot-tests/**/*.{xml,html,log,png,jpg}', allowEmptyArchive: true, fingerprint: true
                    }
                    if (fileExists('coverage')) {
                        archiveArtifacts artifacts: 'coverage/**/*', allowEmptyArchive: true
                    }
                } catch (Exception e) {
                    echo "Warning: Could not archive artifacts: ${e.getMessage()}"
                }
            }
        }

        success {
            echo '✅ Pipeline completed successfully!'
        }

        failure {
            echo '❌ Pipeline failed!'
            
            script {
                try {
                    if (isUnix()) {
                        sh '''
                            echo "=== DIAGNOSTIC INFO ==="
                            docker ps -a | grep shopfer || echo "No shopfer containers found"
                            netstat -tulpn | grep :4200 || echo "Port 4200 not in use"
                            ls -la robot-tests/ || echo "No robot-tests directory"
                            if [ -f app.log ]; then echo "=== APP LOG ==="; tail -20 app.log; fi
                        '''
                    } else {
                        bat '''
                            echo === DIAGNOSTIC INFO ===
                            docker ps -a | find "shopfer" 2>nul || echo No shopfer containers found
                            netstat -an | find "4200" 2>nul || echo Port 4200 not found
                            if exist robot-tests\\output.xml echo Robot test results available
                            if exist app.log type app.log
                        '''
                    }
                } catch (Exception e) {
                    echo "Diagnostic failed: ${e.getMessage()}"
                }
            }
        }
    }
}

pipeline {
    agent any
  environment {
        scannerHome = tool 'Sonar' // Déplacé ici pour être accessible globalement
      }
    
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
        
        stage('Run Docker Container') {
            steps {
                script {
                    try {
                        bat '''
                            docker stop shopfer-container 2>nul || echo off
                            docker rm shopfer-container 2>nul || echo off
                        '''
                    } catch (Exception e) {
                        // Container cleanup failed - continue
                    }
                }
                
                bat 'docker run -d --name shopfer-container -p 4200:4200 shopferimgg'
            }
        }
         stage('Run Sonarqube') {
            steps {
                withSonarQubeEnv(credentialsId: 'SQube-token', installationName: 'SonarQube') {
                    bat "${scannerHome}\\bin\\sonar-scanner.bat"
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
                        } catch (Exception e) {
                            attempt++
                            if (attempt % 10 == 0) {
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
    }
    
    post {
        always {
            script {
                // Container cleanup
                try {
                    bat '''
                        docker stop shopfer-container 2>nul || echo off
                        docker rm shopfer-container 2>nul || echo off
                        for /F %%i in ('docker ps -q --filter "ancestor=shopferimgg" 2^>nul') do (
                            docker stop %%i 2^>nul && docker rm %%i 2^>nul
                        )
                    '''
                } catch (Exception e) {
                    // Cleanup failed - continue
                }
                
                // Process cleanup
                try {
                    bat '''
                        for /f "tokens=5" %%a in ('netstat -aon 2^>nul ^| find ":4200" ^| find "LISTENING"') do (
                            taskkill /f /pid %%a 2^>nul || echo off
                        )
                    '''
                } catch (Exception e) {
                    // Process cleanup failed - continue
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
        }
        
        failure {
            echo 'Pipeline failed ❌'
            
            // Minimal diagnostic on failure
            script {
                try {
                    bat '''
                        echo === DIAGNOSTIC ===
                        docker ps -a | find "shopfer" 2>nul || echo No shopfer containers
                        netstat -an | find "4200" 2>nul || echo Port 4200 not found
                        if exist robot-tests\\output.xml echo Robot test results available
                    '''
                } catch (Exception e) {
                    // Diagnostic failed - continue
                }
            }
        }
    }
}

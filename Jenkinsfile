pipeline {
    agent any
    
    environment {
        APP_URL = 'http://localhost:4200'
        ROBOT_ENV = 'robot-tests\\robot_env'
    }
    
    stages {
        stage('Checkout & Setup') {
            steps {
                git branch: 'main', url: 'https://github.com/Ichrak-dhahri/ShopFer.git'
                bat 'npm install'
            }
        }
        
        stage('Test & Build') {
            parallel {
                stage('Unit Tests') {
                    steps {
                        bat 'npm run test -- --karma-config karma.conf.js --watch=false --code-coverage'
                    }
                }
                stage('Build App') {
                    steps {
                        bat 'npm run build'
                    }
                }
            }
        }
        
        stage('E2E Tests') {
            steps {
                // Démarrer l'app en arrière-plan
                bat 'start /b npm start'
                
                // Attendre que l'app soit prête
                timeout(time: 2, unit: 'MINUTES') {
                    waitUntil {
                        script {
                            try {
                                bat 'curl -f %APP_URL% > nul 2>&1'
                                return true
                            } catch (Exception e) {
                                sleep 5
                                return false
                            }
                        }
                    }
                }
                
                // Setup Robot Framework (une seule fois)
                bat '''
                    if not exist robot-tests mkdir robot-tests
                    cd robot-tests
                    if not exist robot_env (
                        python -m venv robot_env
                        %ROBOT_ENV%\\Scripts\\pip install robotframework robotframework-seleniumlibrary selenium webdriver-manager
                    )
                '''
                
                // Exécuter les tests Robot
                bat '''
                    cd robot-tests
                    %ROBOT_ENV%\\Scripts\\robot --outputdir . ^
                        --variable BROWSER:headlesschrome ^
                        --variable URL:%APP_URL% ^
                        hello.robot
                '''
            }
        }
    }
    
    post {
        always {
            // Nettoyage simple
            bat '''
                for /f "tokens=5" %%a in ('netstat -aon ^| find ":4200" ^| find "LISTENING"') do taskkill /f /pid %%a 2>nul
                taskkill /f /im node.exe 2>nul || echo "No node processes"
            '''
            
            // Publication des résultats
            publishHTML([
                allowMissing: false,
                alwaysLinkToLastBuild: true,
                keepAll: true,
                reportDir: 'robot-tests',
                reportFiles: 'report.html',
                reportName: 'Robot Framework Report'
            ])
            
            archiveArtifacts artifacts: 'robot-tests/**/*.{xml,html,png}', allowEmptyArchive: true
        }
    }
}
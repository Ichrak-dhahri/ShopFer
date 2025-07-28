pipeline {
    agent any
    
    stages {
        stage('Clone & Setup') {
            steps {
                git branch: 'main', url: 'https://github.com/Ichrak-dhahri/ShopFer.git'
                bat 'npm install'
            }
        }
        
        stage('Test & Build') {
            steps {
                bat 'npm run test -- --karma-config karma.conf.js --watch=false --code-coverage'
                bat 'npm run build'
            }
        }
        
        stage('Start App & E2E Tests') {
            steps {
                // Démarrer l'app en arrière-plan
                bat 'start "Angular" /min cmd /c "npm start"'
                
                // Attendre que l'app soit prête
                script {
                    for (int i = 0; i < 15; i++) {
                        try {
                            sleep(2)
                            bat 'netstat -an | find "4200" | find "LISTENING"'
                            break
                        } catch (Exception e) {
                            if (i == 14) error("App failed to start")
                        }
                    }
                }
                
                // Setup Robot Framework et exécuter les tests
                bat '''
                    python -m venv robot_env
                    robot_env\\Scripts\\pip install robotframework robotframework-seleniumlibrary webdriver-manager
                '''
                
                // Créer un test simple si nécessaire
                script {
                    if (!fileExists('test.robot')) {
                        writeFile file: 'test.robot', text: '''*** Settings ***
Library    SeleniumLibrary

*** Test Cases ***
App Loads
    Open Browser    http://localhost:4200    headlesschrome
    Wait Until Page Contains Element    tag:body    timeout=10s
    Page Should Contain Element    tag:body
    Close Browser
'''
                    }
                }
                
                bat 'robot_env\\Scripts\\robot --outputdir . test.robot'
            }
        }
    }
    
    post {
        always {
            // Nettoyer les processus
            bat '''
                for /f "tokens=5" %%a in ('netstat -aon ^| find ":4200" ^| find "LISTENING"') do (
                    taskkill /f /pid %%a 2>nul || echo "Process %%a already stopped"
                )
                taskkill /f /im node.exe 2>nul || echo "No node processes"
                exit /b 0
            '''
            
            // Publier les résultats
            script {
                try {
                    robot outputPath: '.', outputFileName: 'output.xml'
                    archiveArtifacts artifacts: '*.{xml,html}', allowEmptyArchive: true
                } catch (Exception e) {
                    echo "Archive failed: ${e.message}"
                }
            }
        }
    }
}
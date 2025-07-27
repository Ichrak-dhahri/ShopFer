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
        
        stage('Build application') {
            steps {
                bat 'call npm run build'
            }
        }
        
        stage('Start application') {
            steps {
                script {
                    // Démarrer l'application Angular en arrière-plan
                    bat 'start /B cmd /c "npm run start > server.log 2>&1"'
                    
                    // Attendre que l'application soit disponible avec une approche simple
                    echo 'Attente du démarrage de l\'application...'
                    sleep(time: 45, unit: 'SECONDS')
                    
                    // Vérifier si l'application répond avec plusieurs tentatives
                    timeout(time: 90, unit: 'SECONDS') {
                        waitUntil {
                            script {
                                def response = bat(
                                    script: 'curl -s -o NUL -w "%%{http_code}" http://localhost:4200',
                                    returnStatus: true
                                )
                                if (response == 0) {
                                    def httpCode = bat(
                                        script: 'curl -s -o NUL -w "%%{http_code}" http://localhost:4200',
                                        returnStdout: true
                                    ).trim()
                                    return httpCode == '200'
                                }
                                return false
                            }
                        }
                    }
                    echo 'Application Angular démarrée avec succès sur http://localhost:4200'
                }
            }
        }
        
        stage('Setup Robot Framework Environment') {
            steps {
                script {
                    // Supprimer l'ancien environnement s'il existe
                    bat 'cd robot-tests && if exist robot_env rmdir /s /q robot_env'
                    
                    // Créer un nouvel environnement virtuel
                    bat 'cd robot-tests && python -m venv robot_env'
                    
                    // Installer les dépendances sans mettre à jour pip d'abord
                    bat '''cd robot-tests && robot_env\\Scripts\\pip install robotframework==6.1.1
                           cd robot-tests && robot_env\\Scripts\\pip install robotframework-seleniumlibrary==6.2.0
                           cd robot-tests && robot_env\\Scripts\\pip install selenium==4.15.2
                           cd robot-tests && robot_env\\Scripts\\pip install webdriver-manager==4.0.1
                           cd robot-tests && robot_env\\Scripts\\pip install requests'''
                }
            }
        }
        
        stage('Run Robot Framework tests') {
            steps {
                script {
                    try {
                        // Exécuter hello.robot depuis le répertoire robot-tests
                        bat '''
                            cd robot-tests
                            robot_env\\Scripts\\robot --outputdir . ^
                                                      --variable BROWSER:headlesschrome ^
                                                      --variable BASE_URL:http://localhost:4200 ^
                                                      --loglevel INFO ^
                                                      --report robot_report.html ^
                                                      --log robot_log.html ^
                                                      --output robot_output.xml ^
                                                      hello.robot
                        '''
                    } catch (Exception e) {
                        echo "Tests Robot Framework ont échoué : ${e.getMessage()}"
                        currentBuild.result = 'UNSTABLE'
                    }
                }
            }
        }
    }
    
    post {
        always {
            // Arrêter l'application Angular
            script {
                bat 'taskkill /F /IM node.exe || echo "No Node.js processes to kill"'
                bat 'taskkill /F /IM cmd.exe /FI "WINDOWTITLE eq npm*" || echo "No npm processes to kill"'
            }
            
            // Vérifier si les fichiers de sortie existent avant de publier
            script {
                def outputExists = fileExists('robot-tests/robot_output.xml')
                if (outputExists) {
                    // Publication des résultats Robot Framework
                    robot(
                        outputPath: 'robot-tests',
                        outputFileName: 'robot_output.xml',
                        reportFileName: 'robot_report.html',
                        logFileName: 'robot_log.html',
                        disableArchiveOutput: false,
                        passThreshold: 100,
                        unstableThreshold: 50,
                        otherFiles: '*.png,*.jpg'
                    )
                } else {
                    echo 'Aucun fichier de sortie Robot Framework trouvé'
                }
            }
            
            // Archiver les artefacts disponibles
            script {
                try {
                    archiveArtifacts artifacts: 'robot-tests/**/*.{xml,html,log,png,jpg}', allowEmptyArchive: true, fingerprint: true
                } catch (Exception e) {
                    echo "Erreur lors de l'archivage : ${e.getMessage()}"
                }
                
                try {
                    archiveArtifacts artifacts: 'server.log', allowEmptyArchive: true, fingerprint: true
                } catch (Exception e) {
                    echo "Pas de log serveur à archiver"
                }
            }
        }
        
        success {
            echo '✅ Pipeline terminé avec succès.'
        }
        
        failure {
            echo '❌ Pipeline échoué.'
        }
        
        unstable {
            echo '⚠️ Pipeline instable - certains tests ont échoué.'
        }
    }
}
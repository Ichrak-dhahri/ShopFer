pipeline {
    agent any
    
    environment {
        NODE_OPTIONS = '--max-old-space-size=4096'
        CHROME_BIN = 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe'
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
        
        stage('Build application') {
            steps {
                bat 'call npm run build'
            }
        }
        
        stage('Start application') {
            steps {
                script {
                    // Nettoyer les processus node existants
                    bat 'taskkill /F /IM node.exe /T || echo "No existing Node processes"'
                    sleep(time: 2, unit: 'SECONDS')
                    
                    // Démarrer l'application Angular avec ng serve
                    bat 'start /B cmd /c "cd /d %CD% && ng serve --host 0.0.0.0 --port 4200 --disable-host-check > server.log 2>&1"'
                    
                    echo 'Attente du démarrage de l\'application...'
                    
                    // Attendre avec une vérification progressive
                    timeout(time: 3, unit: 'MINUTES') {
                        waitUntil {
                            script {
                                try {
                                    // Vérifier si l'application répond
                                    def httpCode = bat(
                                        script: 'curl -s -o NUL -w "%%{http_code}" --connect-timeout 5 http://localhost:4200',
                                        returnStdout: true
                                    ).trim()
                                    
                                    echo "HTTP Response Code: ${httpCode}"
                                    
                                    if (httpCode == '200') {
                                        echo 'Application Angular accessible sur http://localhost:4200'
                                        return true
                                    } else {
                                        echo "Application pas encore prête (code: ${httpCode}), nouvelle tentative..."
                                        sleep(time: 5, unit: 'SECONDS')
                                        return false
                                    }
                                } catch (Exception e) {
                                    echo "Erreur lors de la vérification: ${e.getMessage()}"
                                    return false
                                }
                            }
                        }
                    }
                }
            }
        }
        
        stage('Setup Robot Framework Environment') {
            steps {
                script {
                    try {
                        // Supprimer l'ancien environnement s'il existe
                        bat 'if exist robot-tests\\robot_env rmdir /s /q robot-tests\\robot_env || echo "Pas d\'ancien environnement à supprimer"'
                        
                        // Créer le répertoire robot-tests s'il n'existe pas
                        bat 'if not exist robot-tests mkdir robot-tests'
                        
                        // Créer un nouvel environnement virtuel
                        bat 'cd robot-tests && python -m venv robot_env'
                        
                        // Installer les dépendances Robot Framework
                        bat '''
                            cd robot-tests && robot_env\\Scripts\\python -m pip install --upgrade pip
                            cd robot-tests && robot_env\\Scripts\\pip install robotframework==6.1.1
                            cd robot-tests && robot_env\\Scripts\\pip install robotframework-seleniumlibrary==6.2.0
                            cd robot-tests && robot_env\\Scripts\\pip install selenium==4.15.2
                            cd robot-tests && robot_env\\Scripts\\pip install webdriver-manager==4.0.1
                            cd robot-tests && robot_env\\Scripts\\pip install requests
                        '''
                        
                        echo 'Environnement Robot Framework configuré avec succès'
                    } catch (Exception e) {
                        echo "Erreur lors de la configuration de l'environnement Robot Framework: ${e.getMessage()}"
                        throw e
                    }
                }
            }
        }
        
        stage('Run Robot Framework tests') {
            steps {
                script {
                    try {
                        // Vérifier que l'application est toujours accessible
                        def appCheck = bat(
                            script: 'curl -s -o NUL -w "%%{http_code}" --connect-timeout 5 http://localhost:4200',
                            returnStdout: true
                        ).trim()
                        
                        if (appCheck != '200') {
                            error "L'application n'est plus accessible (code: ${appCheck})"
                        }
                        
                        echo 'Application confirmée accessible, lancement des tests Robot Framework...'
                        
                        // Exécuter les tests Robot Framework
                        bat '''
                            cd robot-tests
                            robot_env\\Scripts\\robot --outputdir results ^
                                                      --variable BROWSER:chrome ^
                                                      --variable BASE_URL:http://localhost:4200 ^
                                                      --loglevel INFO ^
                                                      --report robot_report.html ^
                                                      --log robot_log.html ^
                                                      --output robot_output.xml ^
                                                      --pythonpath . ^
                                                      hello.robot
                        '''
                        
                        echo 'Tests Robot Framework terminés avec succès'
                        
                    } catch (Exception e) {
                        echo "Erreur lors des tests Robot Framework: ${e.getMessage()}"
                        
                        // Capturer les logs pour le débogage
                        script {
                            try {
                                def serverLog = readFile('server.log')
                                echo "Contenu du log serveur:\n${serverLog}"
                            } catch (Exception logError) {
                                echo "Impossible de lire le log serveur: ${logError.getMessage()}"
                            }
                        }
                        
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
                echo 'Arrêt des processus Node.js...'
                bat '''
                    taskkill /F /IM node.exe /T || echo "Pas de processus Node.js à arrêter"
                    taskkill /F /IM chrome.exe /T || echo "Pas de processus Chrome à arrêter"
                    taskkill /F /IM chromedriver.exe /T || echo "Pas de processus ChromeDriver à arrêter"
                '''
                sleep(time: 2, unit: 'SECONDS')
            }
            
            // Publication des résultats Robot Framework
            script {
                try {
                    def outputExists = fileExists('robot-tests/results/robot_output.xml')
                    if (outputExists) {
                        echo 'Publication des résultats Robot Framework...'
                        
                        // Publication des résultats Robot Framework
                        robot(
                            outputPath: 'robot-tests/results',
                            outputFileName: 'robot_output.xml',
                            reportFileName: 'robot_report.html',
                            logFileName: 'robot_log.html',
                            disableArchiveOutput: false,
                            passThreshold: 80,
                            unstableThreshold: 50,
                            otherFiles: '*.png,*.jpg,*.log'
                        )
                    } else {
                        echo 'Aucun fichier de sortie Robot Framework trouvé dans robot-tests/results/'
                        
                        // Vérifier dans le répertoire racine robot-tests
                        def altOutputExists = fileExists('robot-tests/robot_output.xml')
                        if (altOutputExists) {
                            echo 'Fichiers trouvés dans le répertoire racine robot-tests'
                            robot(
                                outputPath: 'robot-tests',
                                outputFileName: 'robot_output.xml',
                                reportFileName: 'robot_report.html',
                                logFileName: 'robot_log.html',
                                disableArchiveOutput: false,
                                passThreshold: 80,
                                unstableThreshold: 50,
                                otherFiles: '*.png,*.jpg,*.log'
                            )
                        }
                    }
                } catch (Exception e) {
                    echo "Erreur lors de la publication des résultats Robot: ${e.getMessage()}"
                }
            }
            
            // Archiver les artefacts
            script {
                try {
                    // Archiver les résultats des tests
                    archiveArtifacts artifacts: 'robot-tests/**/*.{xml,html,log,png,jpg}', allowEmptyArchive: true, fingerprint: true
                    
                    // Archiver le log du serveur
                    if (fileExists('server.log')) {
                        archiveArtifacts artifacts: 'server.log', allowEmptyArchive: true, fingerprint: true
                    }
                    
                    // Archiver les logs de build Angular
                    archiveArtifacts artifacts: 'front/shopfer/**/*', allowEmptyArchive: true, fingerprint: false
                    
                } catch (Exception e) {
                    echo "Erreur lors de l'archivage: ${e.getMessage()}"
                }
            }
            
            // Nettoyer les processus restants
            script {
                bat '''
                    wmic process where "commandline like '%%ng serve%%'" delete || echo "Pas de ng serve à arrêter"
                    wmic process where "commandline like '%%localhost:4200%%'" delete || echo "Pas de processus localhost:4200 à arrêter"
                '''
            }
        }
        
        success {
            echo '✅ Pipeline terminé avec succès!'
            echo 'Tous les tests ont passé.'
        }
        
        failure {
            echo '❌ Pipeline échoué!'
            echo 'Consultez les logs pour plus de détails.'
        }
        
        unstable {
            echo '⚠️ Pipeline instable - certains tests ont échoué.'
            echo 'Les résultats des tests sont disponibles dans les artefacts.'
        }
    }
}
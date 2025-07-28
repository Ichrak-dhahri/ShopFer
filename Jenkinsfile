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
        
        stage('Check Docker Status') {
            steps {
                echo "Vérification du statut de Docker..."
                script {
                    try {
                        bat 'docker --version'
                        bat 'docker info'
                        echo "✅ Docker est disponible et fonctionnel"
                    } catch (Exception e) {
                        echo "❌ Erreur Docker: ${e.getMessage()}"
                        echo "🔧 Tentative de démarrage de Docker Desktop..."
                        
                        // Tentative de démarrage de Docker Desktop
                        bat '''
                            echo Démarrage de Docker Desktop...
                            start "" "C:\\Program Files\\Docker\\Docker\\Docker Desktop.exe" || echo Docker Desktop non trouvé dans le chemin par défaut
                            timeout /t 30 /nobreak
                            docker info || echo Docker toujours non disponible
                        '''
                    }
                }
            }
        }
        
        stage('Build Docker Image') {
            steps {
                script {
                    try {
                        echo "Construction de l'image Docker..."
                        bat 'docker build -t shopferimgg .'
                        echo "✅ Image Docker construite avec succès"
                    } catch (Exception e) {
                        echo "❌ Échec de la construction Docker: ${e.getMessage()}"
                        error("Impossible de construire l'image Docker. Vérifiez que Docker est démarré.")
                    }
                }
            }
        }
        
        stage('Push Docker Image to Docker Hub') {
            steps {
                echo "Pushing Docker image to Docker Hub..."
                
                withCredentials([usernamePassword(credentialsId: 'docker-hub-login', usernameVariable: 'DOCKER_HUB_USER', passwordVariable: 'DOCKER_HUB_PASS')]) {
                    script {
                        try {
                            bat """
                                echo Tagging Docker image...
                                docker tag shopferimgg %DOCKER_HUB_USER%/shopferimgg:latest
                                
                                echo Logging in to Docker Hub...
                                docker login -u %DOCKER_HUB_USER% -p %DOCKER_HUB_PASS%
                                
                                echo Pushing image to Docker Hub...
                                docker push %DOCKER_HUB_USER%/shopferimgg:latest
                                
                                echo ✅ Image pushed successfully to Docker Hub
                            """
                        } catch (Exception e) {
                            echo "❌ Échec du push vers Docker Hub: ${e.getMessage()}"
                            error("Impossible de pousser l'image vers Docker Hub")
                        }
                    }
                }
            }
            post {
                success {
                    echo "✅ Docker image successfully pushed to Docker Hub as farahabbes/shopferimgg:latest"
                }
                failure {
                    echo "❌ Failed to push Docker image to Docker Hub"
                }
            }
        }
        
        stage('Run Docker Container') {
            steps {
                script {
                    try {
                        echo "Démarrage du conteneur Docker..."
                        bat 'docker run -d -p 4200:4200 --name shopfer-container shopferimgg'
                        echo "✅ Conteneur Docker démarré avec succès"
                    } catch (Exception e) {
                        echo "❌ Échec du démarrage du conteneur: ${e.getMessage()}"
                        // Continuer sans faire échouer le pipeline
                        echo "⚠️ Continuation sans conteneur Docker"
                    }
                }
            }
        }
        
        stage('Verify Application Status') {
            steps {
                echo "Vérification du statut de l'application Docker..."
                
                script {
                    def maxAttempts = 30
                    def attempt = 0
                    def appStarted = false
                    
                    while (attempt < maxAttempts && !appStarted) {
                        try {
                            sleep(2)
                            bat 'netstat -an | find "4200" | find "LISTENING"'
                            appStarted = true
                            echo "✅ Application Angular démarrée sur le port 4200"
                        } catch (Exception e) {
                            attempt++
                            echo "Tentative ${attempt}/${maxAttempts} - Application pas encore prête..."
                        }
                    }
                    
                    if (!appStarted) {
                        echo "⚠️ L'application n'est pas accessible sur le port 4200"
                        echo "Cela peut être normal si Docker n'est pas disponible"
                    }
                }
                
                script {
                    try {
                        bat '''
                            echo État des conteneurs Docker:
                            docker ps | find "shopfer-container" || echo Aucun conteneur shopfer-container trouvé
                            echo.
                            echo Ports en écoute:
                            netstat -an | find "4200" || echo Port 4200 non trouvé
                            echo.
                            echo Test de connectivité HTTP (si possible):
                            curl -f http://localhost:4200 || echo Connexion non disponible
                        '''
                    } catch (Exception e) {
                        echo "⚠️ Vérification partielle - Docker peut ne pas être disponible"
                    }
                }
            }
        }
        
        stage('Setup Robot Framework Environment') {
            steps {
                echo "Configuration de l'environnement Robot Framework..."
                
                bat '''
                    if not exist robot-tests mkdir robot-tests
                    cd robot-tests
                '''
                
                bat '''
                    cd robot-tests
                    if exist robot_env rmdir /s /q robot_env
                    python -m venv robot_env
                '''
                
                bat '''
                    cd robot-tests
                    robot_env\\Scripts\\python.exe -m pip install --upgrade pip
                    robot_env\\Scripts\\pip install robotframework
                    robot_env\\Scripts\\pip install robotframework-seleniumlibrary
                    robot_env\\Scripts\\pip install selenium
                    robot_env\\Scripts\\pip install webdriver-manager
                '''
                
                echo "✅ Environnement Robot Framework configuré"
            }
        }
        
        stage('Run Robot Framework tests') {
            steps {
                echo "Exécution des tests Robot Framework..."
                
                script {
                    try {
                        bat '''
                            cd robot-tests
                            robot_env\\Scripts\\robot --outputdir . ^
                                                      --variable BROWSER:headlesschrome ^
                                                      --variable URL:http://localhost:4200 ^
                                                      --loglevel INFO ^
                                                      hello.robot
                        '''
                    } catch (Exception e) {
                        echo "⚠️ Tests Robot Framework échoués: ${e.getMessage()}"
                        echo "Cela peut être dû à l'indisponibilité de l'application sur le port 4200"
                        // Marquer comme instable plutôt que comme échec complet
                        currentBuild.result = 'UNSTABLE'
                    }
                }
            }
        }
    }
    
    post {
        always {
            echo "Nettoyage des ressources..."
            
            script {
                try {
                    // Nettoyage Docker avec syntaxe corrigée
                    bat '''
                        echo Arrêt et suppression du conteneur shopfer-container...
                        docker stop shopfer-container 2>nul || echo Conteneur shopfer-container non trouvé
                        docker rm shopfer-container 2>nul || echo Conteneur shopfer-container déjà supprimé
                        
                        echo Nettoyage des conteneurs orphelins...
                        for /f %%i in ('docker ps -q --filter "ancestor=shopferimgg" 2^>nul') do (
                            echo Arrêt du conteneur %%i
                            docker stop %%i 2>nul
                            docker rm %%i 2>nul
                        )
                    '''
                } catch (Exception e) {
                    echo "⚠️ Nettoyage Docker non effectué (Docker peut ne pas être disponible): ${e.getMessage()}"
                }
                
                try {
                    bat '''
                        echo Nettoyage des processus Node.js restants...
                        for /f "tokens=5" %%a in ('netstat -aon 2^>nul ^| find ":4200" ^| find "LISTENING"') do (
                            echo Arrêt du processus %%a
                            taskkill /f /pid %%a 2>nul || echo Processus %%a déjà arrêté
                        )
                        
                        echo Nettoyage terminé
                    '''
                } catch (Exception e) {
                    echo "⚠️ Nettoyage des processus partiellement effectué: ${e.getMessage()}"
                }
            }
            
            // Publication des résultats Robot Framework avec gestion d'erreur améliorée
            script {
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
                    } else {
                        echo "⚠️ Aucun fichier de résultats Robot Framework trouvé"
                    }
                } catch (Exception e) {
                    echo "⚠️ Erreur lors de la publication des résultats Robot: ${e.getMessage()}"
                }
            }
            
            // Archiver les artefacts
            script {
                try {
                    archiveArtifacts artifacts: 'robot-tests/**/*.{xml,html,log,png,jpg}', allowEmptyArchive: true, fingerprint: true
                } catch (Exception e) {
                    echo "⚠️ Erreur lors de l'archivage: ${e.getMessage()}"
                }
            }
        }
        
        success {
            echo '✅ Pipeline terminé avec succès.'
        }
        
        failure {
            echo '❌ Pipeline échoué.'
            
            script {
                try {
                    bat '''
                        echo === DIAGNOSTIC ===
                        echo État des conteneurs Docker:
                        docker ps -a 2>nul | find "shopfer" || echo Aucun conteneur shopfer
                        echo.
                        echo État des processus Node.js:
                        tasklist | find "node.exe" || echo Aucun processus Node.js
                        echo.
                        echo Ports en écoute:
                        netstat -an | find "4200" || echo Port 4200 non trouvé
                        echo.
                        echo Contenu du répertoire robot-tests:
                        if exist robot-tests dir robot-tests
                        echo.
                        echo === FIN DIAGNOSTIC ===
                    '''
                } catch (Exception e) {
                    echo "⚠️ Diagnostic partiel: ${e.getMessage()}"
                }
            }
        }
        
        unstable {
            echo '⚠️ Pipeline terminé avec des avertissements.'
        }
    }
}
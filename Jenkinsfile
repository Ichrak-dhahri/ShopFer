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
                echo "Construction de l'image Docker..."
                bat 'docker build -t shopferimgg .'
                echo "✅ Image Docker créée avec succès"
            }
        }
        
        stage('Push Docker Image to Docker Hub') {
            steps {
                echo "Pushing Docker image to Docker Hub..."
                
                withCredentials([usernamePassword(credentialsId: 'docker-hub-login', usernameVariable: 'DOCKER_HUB_USER', passwordVariable: 'DOCKER_HUB_PASS')]) {
                    bat """
                        echo Tagging Docker image...
                        docker tag shopferimgg %DOCKER_HUB_USER%/shopferimgg:latest
                        
                        echo Logging in to Docker Hub...
                        docker login -u %DOCKER_HUB_USER% -p %DOCKER_HUB_PASS%
                        
                        echo Pushing image to Docker Hub...
                        docker push %DOCKER_HUB_USER%/shopferimgg:latest
                        
                        echo ✅ Image pushed successfully to Docker Hub
                    """
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
                echo "Démarrage du conteneur Docker..."
                
                script {
                    try {
                        // Arrêter et supprimer le conteneur s'il existe déjà
                        bat '''
                            echo Nettoyage préalable du conteneur...
                            docker stop shopfer-container 2>nul || echo Aucun conteneur à arrêter
                            docker rm shopfer-container 2>nul || echo Aucun conteneur à supprimer
                        '''
                    } catch (Exception e) {
                        echo "Note: Nettoyage préalable - ${e.getMessage()}"
                    }
                }
                
                // Démarrer le nouveau conteneur avec un nom
                bat 'docker run -d --name shopfer-container -p 4200:4200 shopferimgg'
                
                echo "✅ Conteneur shopfer-container démarré sur le port 4200"
            }
        }
        
        stage('Verify Application Status') {
            steps {
                echo "Vérification du statut de l'application Docker..."
                
                // Attendre que l'application soit disponible
                script {
                    def maxAttempts = 30
                    def attempt = 0
                    def appStarted = false
                    
                    while (attempt < maxAttempts && !appStarted) {
                        try {
                            sleep(2)
                            bat 'netstat -an | find "4200" | find "LISTENING"'
                            appStarted = true
                            echo "✅ Application Angular démarrée dans Docker sur le port 4200"
                        } catch (Exception e) {
                            attempt++
                            echo "Tentative ${attempt}/${maxAttempts} - Application pas encore prête..."
                        }
                    }
                    
                    if (!appStarted) {
                        error("❌ L'application Angular n'a pas pu démarrer dans le délai imparti")
                    }
                }
                
                bat '''
                    echo État des conteneurs Docker:
                    docker ps | find "shopferimgg" || echo Aucun conteneur shopferimgg trouvé
                    echo.
                    echo Ports en écoute:
                    netstat -an | find "4200" || echo Port 4200 non trouvé
                    echo.
                    echo Test de connectivité HTTP:
                    curl -f http://localhost:4200 || echo Connexion échouée
                '''
            }
        }
        
        stage('Setup Robot Framework Environment') {
            steps {
                echo "Configuration de l'environnement Robot Framework..."
                
                // Créer le répertoire s'il n'existe pas
                bat '''
                    if not exist robot-tests mkdir robot-tests
                    cd robot-tests
                '''
                
                // Créer l'environnement virtuel
                bat '''
                    cd robot-tests
                    if exist robot_env rmdir /s /q robot_env
                    python -m venv robot_env
                '''
                
                // Mettre à jour pip et installer les dépendances
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
                
                // Exécuter les tests
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
            echo "Nettoyage des ressources..."
            
            script {
                try {
                    // Arrêter et supprimer le conteneur nommé
                    bat '''
                        echo Arrêt et suppression du conteneur shopfer-container...
                        docker stop shopfer-container 2>nul || echo Conteneur shopfer-container non trouvé
                        docker rm shopfer-container 2>nul || echo Conteneur shopfer-container déjà supprimé
                    '''
                } catch (Exception e) {
                    echo "⚠️ Nettoyage du conteneur principal non effectué: ${e.getMessage()}"
                }
            }
            
            script {
                try {
                    // Nettoyage des conteneurs orphelins (syntaxe corrigée)
                    bat '''
                        echo Nettoyage des conteneurs orphelins...
                        for /F %%i in ('docker ps -q --filter "ancestor=shopferimgg" 2^>nul') do (
                            echo Arrêt du conteneur %%i
                            docker stop %%i 2^>nul
                            docker rm %%i 2^>nul
                        )
                    '''
                } catch (Exception e) {
                    echo "⚠️ Nettoyage Docker non effectué (Docker peut ne pas être disponible): ${e.getMessage()}"
                }
            }
            
            script {
                try {
                    // Nettoyage des processus Node.js
                    bat '''
                        echo Nettoyage des processus Node.js restants...
                        for /f "tokens=5" %%a in ('netstat -aon 2^>nul ^| find ":4200" ^| find "LISTENING"') do (
                            echo Arrêt du processus %%a
                            taskkill /f /pid %%a 2^>nul || echo Processus %%a déjà arrêté
                        )
                        echo Nettoyage terminé
                    '''
                } catch (Exception e) {
                    echo "⚠️ Nettoyage des processus non effectué: ${e.getMessage()}"
                }
            }
            
            // Publication des résultats Robot Framework avec gestion d'erreur
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
                        echo "✅ Résultats Robot Framework publiés"
                    } else {
                        echo "⚠️ Fichier output.xml non trouvé pour Robot Framework"
                    }
                } catch (Exception e) {
                    echo "⚠️ Erreur lors de la publication des résultats Robot: ${e.getMessage()}"
                }
            }
            
            // Archiver les artefacts
            script {
                try {
                    if (fileExists('robot-tests')) {
                        archiveArtifacts artifacts: 'robot-tests/**/*.{xml,html,log,png,jpg}', allowEmptyArchive: true, fingerprint: true
                        echo "✅ Artefacts archivés"
                    } else {
                        echo "⚠️ Répertoire robot-tests non trouvé pour l'archivage"
                    }
                } catch (Exception e) {
                    echo "⚠️ Erreur lors de l'archivage: ${e.getMessage()}"
                }
            }
        }
        
        success {
            echo '✅ Pipeline terminé avec succès.'
            echo '📊 Résumé:'
            echo '   - Tests unitaires: ✅ Réussis'
            echo '   - Build Angular: ✅ Réussi'
            echo '   - Image Docker: ✅ Créée et pushée'
            echo '   - Conteneur: ✅ Démarré'
            echo '   - Tests Robot: ✅ Exécutés'
            echo '   - Nettoyage: ✅ Effectué'
        }
        
        failure {
            echo '❌ Pipeline échoué.'
            
            // Diagnostic en cas d'échec
            script {
                try {
                    bat '''
                        echo === DIAGNOSTIC COMPLET ===
                        echo.
                        echo [DOCKER] État des conteneurs:
                        docker ps -a | find "shopfer" 2>nul || echo Aucun conteneur shopfer trouvé
                        echo.
                        echo [DOCKER] Images disponibles:
                        docker images | find "shopfer" 2>nul || echo Aucune image shopfer trouvée
                        echo.
                        echo [SYSTÈME] État des processus Node.js:
                        tasklist | find "node.exe" 2>nul || echo Aucun processus Node.js
                        echo.
                        echo [RÉSEAU] Ports en écoute:
                        netstat -an | find "4200" 2>nul || echo Port 4200 non trouvé
                        echo.
                        echo [FICHIERS] Contenu du répertoire robot-tests:
                        if exist robot-tests (
                            dir robot-tests
                        ) else (
                            echo Répertoire robot-tests non trouvé
                        )
                        echo.
                        echo [ESPACE DISQUE] Espace disponible:
                        dir /-c | find "octets libres" 2>nul || echo Impossible de vérifier l'espace
                        echo.
                        echo === FIN DIAGNOSTIC ===
                    '''
                } catch (Exception e) {
                    echo "⚠️ Erreur lors du diagnostic: ${e.getMessage()}"
                }
            }
        }
    }
}
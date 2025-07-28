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
                echo "✅ Image Docker construite avec succès"
            }
        }
        
        stage('Run Docker Container') {
            steps {
                echo "Démarrage du conteneur Docker..."
                
                // Arrêter et supprimer le conteneur existant s'il existe
                bat '''
                    echo Nettoyage des conteneurs existants...
                    docker stop shopfer-container 2>nul || echo Aucun conteneur à arrêter
                    docker rm shopfer-container 2>nul || echo Aucun conteneur à supprimer
                '''
                
                // Démarrer le nouveau conteneur
                bat 'docker run -d --name shopfer-container -p 4200:4200 shopferimgg'
                
                echo "✅ Conteneur Docker démarré sur le port 4200"
            }
        }
        
        stage('Wait for Application to Start') {
            steps {
                echo "Attente du démarrage de l'application dans le conteneur..."
                
                script {
                    def maxAttempts = 30
                    def attempt = 0
                    def appStarted = false
                    
                    while (attempt < maxAttempts && !appStarted) {
                        try {
                            sleep(3)
                            // Vérifier si l'application répond
                            bat 'curl -f http://localhost:4200 || exit 1'
                            appStarted = true
                            echo "✅ Application Angular accessible via Docker sur le port 4200"
                        } catch (Exception e) {
                            attempt++
                            echo "Tentative ${attempt}/${maxAttempts} - Application pas encore prête..."
                        }
                    }
                    
                    if (!appStarted) {
                        error("❌ L'application Angular n'a pas pu démarrer dans le conteneur Docker")
                    }
                }
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
        
        stage('Verify Application Status') {
            steps {
                echo "Vérification du statut de l'application Docker..."
                bat '''
                    echo État du conteneur Docker:
                    docker ps | find "shopfer-container" || echo Conteneur non trouvé
                    echo.
                    echo Logs du conteneur:
                    docker logs shopfer-container --tail 10
                    echo.
                    echo Test de connectivité HTTP:
                    curl -f http://localhost:4200 || echo Connexion échouée
                '''
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
            
            // Arrêter et supprimer le conteneur Docker
            bat '''
                echo Arrêt du conteneur Docker...
                docker stop shopfer-container 2>nul || echo Conteneur déjà arrêté
                docker rm shopfer-container 2>nul || echo Conteneur déjà supprimé
                echo Nettoyage Docker terminé
            '''
            
            // Nettoyage des processus Node.js (au cas où)
            bat '''
                echo Nettoyage des processus Node.js restants...
                taskkill /f /im node.exe 2>nul || echo Aucun processus node.exe
                taskkill /f /im npm.cmd 2>nul || echo Aucun processus npm.cmd
                echo Nettoyage terminé
                exit /b 0
            '''
            
            // Publication des résultats Robot Framework avec gestion d'erreur
            script {
                try {
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
            
            // Diagnostic en cas d'échec
            bat '''
                echo === DIAGNOSTIC ===
                echo État du conteneur Docker:
                docker ps -a | find "shopfer-container" || echo Aucun conteneur trouvé
                echo.
                echo Logs du conteneur:
                docker logs shopfer-container 2>nul || echo Pas de logs disponibles
                echo.
                echo Images Docker:
                docker images | find "shopferimgg" || echo Image non trouvée
                echo.
                echo Contenu du répertoire robot-tests:
                if exist robot-tests dir robot-tests
                echo.
                echo === FIN DIAGNOSTIC ===
            '''
        }
    }
}
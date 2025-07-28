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
        
        stage('Start Angular Application') {
            steps {
                // Démarrer l'application Angular en arrière-plan de façon plus robuste
                bat '''
                    echo Démarrage de l application Angular...
                    start "Angular App" /min cmd /c "npm run start"
                    echo Attente du démarrage de l application...
                '''
                
                // Attendre que l'application soit disponible avec une vérification
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
                        error("❌ L'application Angular n'a pas pu démarrer dans le délai imparti")
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
                echo "Vérification du statut de l'application..."
                bat '''
                    echo État des processus Node.js:
                    tasklist | find "node.exe" || echo Aucun processus Node.js trouvé
                    echo.
                    echo Ports en écoute:
                    netstat -an | find "4200" || echo Port 4200 non trouvé
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
        
        stage('Stop Angular Application') {
            steps {
                echo "Arrêt de l'application Angular avant la conteneurisation..."
                bat '''
                    echo Arrêt des processus Node.js sur le port 4200...
                    for /f "tokens=5" %%a in ('netstat -aon 2^>nul ^| find ":4200" ^| find "LISTENING"') do (
                        echo Arrêt du processus %%a
                        taskkill /f /pid %%a 2>nul || echo Processus %%a déjà arrêté
                    )
                    
                    echo Arrêt de tous les processus npm et node...
                    taskkill /f /im node.exe 2>nul || echo Aucun processus node.exe
                    taskkill /f /im npm.cmd 2>nul || echo Aucun processus npm.cmd
                    
                    echo Application Angular arrêtée
                '''
            }
        }
        
        stage('Build Docker Image') {
            steps {
                echo "Construction de l'image Docker..."
                bat 'docker build -t shopferimgg .'
                echo "✅ Image Docker 'shopferimgg' créée avec succès"
            }
        }
        
        stage('Clean up existing Docker containers') {
            steps {
                echo "Nettoyage des conteneurs Docker existants..."
                script {
                    try {
                        bat '''
                            echo Nettoyage des conteneurs existants...
                            docker stop shopfer-container 2>nul || echo Aucun conteneur à arrêter
                            docker rm shopfer-container 2>nul || echo Aucun conteneur à supprimer
                            
                            echo Libération du port 4200...
                            for /f "tokens=5" %%a in ('netstat -aon 2^>nul ^| find ":4200" ^| find "LISTENING"') do (
                                taskkill /f /pid %%a 2>nul || echo Port 4200 déjà libre
                            )
                        '''
                    } catch (Exception e) {
                        echo "⚠️ Nettoyage terminé avec avertissements"
                    }
                }
            }
        }
        
        stage('Run Docker Container') {
            steps {
                echo "Démarrage du conteneur Docker..."
                script {
                    try {
                        bat 'docker run -d -p 4200:80 --name shopfer-container shopferimgg'
                        echo "✅ Conteneur Docker démarré"
                        
                        // Vérifier que le conteneur fonctionne
                        def maxAttempts = 15
                        def attempt = 0
                        def containerRunning = false
                        
                        while (attempt < maxAttempts && !containerRunning) {
                            try {
                                sleep(3)
                                bat 'docker ps | find "shopfer-container"'
                                containerRunning = true
                                echo "✅ Conteneur Docker fonctionne correctement"
                            } catch (Exception e) {
                                attempt++
                                echo "Tentative ${attempt}/${maxAttempts} - Vérification du conteneur..."
                            }
                        }
                        
                        if (!containerRunning) {
                            echo "⚠️ Le conteneur pourrait avoir des problèmes. Vérification des logs..."
                            bat 'docker logs shopfer-container || echo Pas de logs disponibles'
                        }
                        
                    } catch (Exception e) {
                        echo "❌ Erreur lors du démarrage du conteneur: ${e.getMessage()}"
                        bat 'docker logs shopfer-container 2>nul || echo Pas de logs disponibles'
                        throw e
                    }
                }
                
                echo "🐳 Application ShopFer déployée dans le conteneur Docker"
            }
        }
    }
    
    post {
        always {
            echo "Nettoyage des ressources..."
            
            script {
                try {
                    // Arrêter l'application Angular
                    bat '''
                        echo Arrêt des processus Node.js...
                        for /f "tokens=5" %%a in ('netstat -aon 2^>nul ^| find ":4200" ^| find "LISTENING"') do (
                            taskkill /f /pid %%a 2>nul || echo Processus %%a déjà arrêté
                        )
                        
                        taskkill /f /im node.exe 2>nul || echo Aucun processus node.exe
                        taskkill /f /im npm.cmd 2>nul || echo Aucun processus npm.cmd
                        exit /b 0
                    '''
                } catch (Exception e) {
                    echo "⚠️ Nettoyage des processus Node.js terminé avec avertissements"
                }
                
                // Publication des résultats Robot Framework
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
                
                // Archiver les artefacts
                try {
                    archiveArtifacts artifacts: 'robot-tests/**/*.{xml,html,log,png,jpg}', allowEmptyArchive: true, fingerprint: true
                } catch (Exception e) {
                    echo "⚠️ Erreur lors de l'archivage: ${e.getMessage()}"
                }
            }
        }
        
        success {
            echo '✅ Pipeline terminé avec succès.'
            echo '🐳 Application ShopFer disponible via Docker sur http://localhost:4200'
        }
        
        failure {
            echo '❌ Pipeline échoué.'
            
            script {
                try {
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
                    
                    // Nettoyer les conteneurs en cas d'échec
                    bat '''
                        echo Nettoyage des conteneurs Docker...
                        docker stop shopfer-container 2>nul || echo Aucun conteneur à arrêter
                        docker rm shopfer-container 2>nul || echo Aucun conteneur à supprimer
                    '''
                } catch (Exception e) {
                    echo "⚠️ Diagnostic terminé avec avertissements"
                }
            }
        }
        
        cleanup {
            echo "Nettoyage final..."
            script {
                try {
                    bat '''
                        echo Arrêt du conteneur Docker...
                        docker stop shopfer-container 2>nul || echo Conteneur déjà arrêté
                        docker rm shopfer-container 2>nul || echo Conteneur déjà supprimé
                        echo Nettoyage Docker terminé
                    '''
                } catch (Exception e) {
                    echo "⚠️ Nettoyage final terminé"
                }
            }
        }
    }
}
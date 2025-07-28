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
                
                // Vérifier que le fichier de test existe
                script {
                    if (!fileExists('robot-tests/hello.robot')) {
                        echo "⚠️ Le fichier hello.robot n'existe pas, création d'un test simple..."
                        
                        writeFile file: 'robot-tests/hello.robot', text: '''*** Settings ***
Documentation    Test simple pour vérifier l'application Angular
Library          SeleniumLibrary

*** Variables ***
\${BASE_URL}    http://localhost:4200
\${BROWSER}     headlesschrome

*** Test Cases ***
Test Application Loading
    [Documentation]    Vérifier que l'application se charge
    Open Browser    \${BASE_URL}    \${BROWSER}
    Wait Until Page Contains Element    tag:body    timeout=10s
    Title Should Contain    ShopFer
    Close Browser
'''
                    }
                }
                
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
            echo "Nettoyage des processus..."
            
            // Arrêter l'application Angular de façon plus robuste
            bat '''
                echo Arrêt des processus Node.js sur le port 4200...
                for /f "tokens=5" %%a in ('netstat -aon 2^>nul ^| find ":4200" ^| find "LISTENING"') do (
                    echo Arrêt du processus %%a
                    taskkill /f /pid %%a 2>nul || echo Processus %%a déjà arrêté
                )
                
                echo Arrêt de tous les processus npm et node...
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
        }
    }
}
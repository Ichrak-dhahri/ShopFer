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
                bat 'npm install'
            }
        }

        stage('Run unit tests') {
            steps {
                bat 'npm run test -- --karma-config karma.conf.js --watch=false --code-coverage'
            }
        }

        stage('Build Angular Application') {
            steps {
                bat 'npm run build'
            }
        }

        stage('Start Angular Application') {
            steps {
                bat '''
                    echo Starting Angular App...
                    start "Angular App" /min cmd /c "npm run start"
                '''
                script {
                    def maxAttempts = 30
                    def attempt = 0
                    def appStarted = false

                    while (attempt < maxAttempts && !appStarted) {
                        sleep time: 2, unit: 'SECONDS'
                        def result = bat(script: 'netstat -an | find "4200" | find "LISTENING"', returnStatus: true)
                        if (result == 0) {
                            appStarted = true
                            echo "✅ Application Angular démarrée sur le port 4200"
                        } else {
                            attempt++
                            echo "⏳ Tentative ${attempt}/${maxAttempts} - Application pas encore prête..."
                        }
                    }

                    if (!appStarted) {
                        error("❌ L'application Angular n'a pas démarré à temps.")
                    }
                }
            }
        }

        stage('Setup Robot Framework Environment') {
            steps {
                echo "🔧 Configuration de l'environnement Robot Framework..."
                bat '''
                    if not exist robot-tests mkdir robot-tests
                    cd robot-tests && (
                        if exist robot_env rmdir /s /q robot_env
                        python -m venv robot_env
                        robot_env\\Scripts\\python.exe -m pip install --upgrade pip
                        robot_env\\Scripts\\pip install robotframework robotframework-seleniumlibrary selenium webdriver-manager
                    )
                '''
            }
        }

        stage('Verify Application Status') {
            steps {
                echo "🔎 Vérification du statut de l'application..."
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
                echo "🧪 Exécution des tests Robot Framework..."
                bat '''
                    cd robot-tests && robot_env\\Scripts\\robot --outputdir . ^
                        --variable BROWSER:headlesschrome ^
                        --variable URL:http://localhost:4200 ^
                        --loglevel INFO ^
                        hello.robot
                '''
            }
        }

        // NEW: Verify Docker before building
        stage('Verify Docker') {
            steps {
                echo "🐳 Vérification de Docker..."
                script {
                    try {
                        bat 'docker --version'
                        bat 'docker info'
                        echo "✅ Docker est disponible"
                    } catch (Exception e) {
                        error("❌ Docker n'est pas disponible. Veuillez démarrer Docker Desktop ou le service Docker. Erreur: ${e.getMessage()}")
                    }
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                echo "🐳 Construction de l'image Docker..."
                bat 'docker build -t shopferimgg .'
            }
        }

        stage('Stop existing containers') {
            steps {
                echo "🛑 Arrêt des conteneurs existants..."
                script {
                    try {
                        bat 'docker stop $(docker ps -q --filter "ancestor=shopferimgg") 2>nul || echo Aucun conteneur à arrêter'
                        bat 'docker rm $(docker ps -aq --filter "ancestor=shopferimgg") 2>nul || echo Aucun conteneur à supprimer'
                    } catch (Exception e) {
                        echo "⚠️ Erreur lors de l'arrêt des conteneurs: ${e.getMessage()}"
                    }
                }
            }
        }

        stage('Run Docker Container') {
            steps {
                echo "🚀 Démarrage du conteneur Docker..."
                bat 'docker run -d -p 4201:4200 --name shopfer-container shopferimgg'
                
                // Verify container is running
                script {
                    sleep time: 5, unit: 'SECONDS'
                    def result = bat(script: 'docker ps | find "shopfer-container"', returnStatus: true)
                    if (result == 0) {
                        echo "✅ Conteneur Docker démarré avec succès"
                        echo "🌐 Application disponible sur http://localhost:4201"
                    } else {
                        error("❌ Le conteneur Docker n'a pas démarré correctement")
                    }
                }
            }
        }
    }

    post {
        always {
            echo "🧹 Nettoyage des processus..."
            bat '''
                echo Arrêt des processus Node.js sur le port 4200...
                for /f "tokens=5" %%a in ('netstat -aon 2^>nul ^| find ":4200" ^| find "LISTENING"') do (
                    echo Arrêt du processus %%a
                    taskkill /f /pid %%a 2>nul || echo Processus %%a déjà arrêté
                )
                taskkill /f /im node.exe 2>nul || echo Aucun processus node.exe
                taskkill /f /im npm.cmd 2>nul || echo Aucun processus npm.cmd
            '''

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
            echo '🌐 Application Angular disponible sur http://localhost:4201 (Docker)'
        }

        failure {
            echo '❌ Pipeline échoué.'
            bat '''
                echo === DIAGNOSTIC ===
                echo Docker status:
                docker ps -a | find "shopfer" 2>nul || echo Aucun conteneur shopfer
                echo.
                echo Node.js processes:
                tasklist | find "node.exe" || echo Aucun processus Node.js
                echo.
                echo Port 4200 status:
                netstat -an | find "4200" || echo Port 4200 non trouvé
                echo.
                echo Robot tests directory:
                if exist robot-tests dir robot-tests
                echo === FIN DIAGNOSTIC ===
            '''
        }

        cleanup {
            echo "🧽 Nettoyage final..."
            script {
                try {
                    // Clean up Docker containers
                    bat 'docker stop shopfer-container 2>nul || echo Container already stopped'
                    bat 'docker rm shopfer-container 2>nul || echo Container already removed'
                } catch (Exception e) {
                    echo "⚠️ Erreur lors du nettoyage Docker: ${e.getMessage()}"
                }
            }
        }
    }
}
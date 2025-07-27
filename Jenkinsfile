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
                // Démarrer l'application Angular en arrière-plan
                bat 'start /B npm run start'
                
                // Vérifier que l'application répond sur le port 4200
                bat '''
                    echo Attente du demarrage de l application...
                    for /L %%i in (1,1,30) do (
                        netstat -an | find ":4200" | find "LISTENING" >nul
                        if !errorlevel!==0 (
                            echo Application Angular demarree sur le port 4200
                            goto :ready
                        )
                        timeout /t 2 >nul 2>&1
                    )
                    echo Timeout: Application non demarree
                    :ready
                '''
            }
        }
        
        stage('Setup Robot Framework Environment') {
            steps {
                // Créer l'environnement virtuel dans robot-tests
                bat 'cd robot-tests && python -m venv robot_env'
                
                // Mettre à jour pip dans l'environnement virtuel
                bat 'cd robot-tests && robot_env\\Scripts\\python -m pip install --upgrade pip'
                
                // Installer Robot Framework et ses dépendances
                bat 'cd robot-tests && robot_env\\Scripts\\pip install robotframework'
                bat 'cd robot-tests && robot_env\\Scripts\\pip install robotframework-seleniumlibrary'
                bat 'cd robot-tests && robot_env\\Scripts\\pip install selenium'
                bat 'cd robot-tests && robot_env\\Scripts\\pip install webdriver-manager'
            }
        }
        
        stage('Run Robot Framework tests') {
            steps {
                // Exécuter hello.robot depuis le répertoire robot-tests
                bat '''
                    cd robot-tests
                    robot_env\\Scripts\\robot --outputdir . ^
                                              --variable BROWSER:headlesschrome ^
                                              --variable URL:http://localhost:4200 ^
                                              hello.robot
                '''
            }
        }
    }
    
    post {
        always {
            // Arrêter l'application Angular (même si le pipeline échoue)
            script {
                bat '''
                    for /f "tokens=5" %%a in ('netstat -aon ^| find ":4200" ^| find "LISTENING"') do taskkill /f /pid %%a 2>nul
                    exit 0
                '''
            }
            
            // Publication des résultats Robot Framework seulement si les fichiers existent
            script {
                if (fileExists('robot-tests/output.xml')) {
                    robot(
                        outputPath: 'robot-tests',
                        outputFileName: 'output.xml',
                        reportFileName: 'report.html',
                        logFileName: 'log.html',
                        disableArchiveOutput: false,
                        passThreshold: 100,
                        unstableThreshold: 90,
                        otherFiles: '*.png,*.jpg'
                    )
                } else {
                    echo 'Aucun fichier de résultats Robot Framework trouvé'
                }
            }
            
            // Archiver les artefacts seulement s'ils existent
            script {
                try {
                    archiveArtifacts artifacts: 'robot-tests/**/*.{xml,html,log,png,jpg}', fingerprint: true, allowEmptyArchive: true
                } catch (Exception e) {
                    echo "Aucun artefact Robot Framework à archiver: ${e.getMessage()}"
                }
            }
        }
        
        success {
            echo '✅ Pipeline terminé avec succès.'
        }
        
        failure {
            echo '❌ Pipeline échoué.'
        }
    }
}
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
                    bat 'start /B npm run start'
                    
                    // Attendre que l'application soit disponible
                    timeout(time: 120, unit: 'SECONDS') {
                        waitUntil {
                            script {
                                def response = bat(
                                    script: 'curl -s -o NUL -w "%%{http_code}" http://localhost:4200',
                                    returnStatus: true
                                )
                                return response == 0
                            }
                        }
                    }
                    echo 'Application Angular démarrée avec succès sur http://localhost:4200'
                }
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
                                              --variable BASE_URL:http://localhost:4200 ^s
                                              --loglevel DEBUG ^
                                              hello.robot
                '''
            }
        }
    }
    
    post {
        always {
            // Arrêter l'application Angular
            script {
                bat 'taskkill /F /IM node.exe || echo "No Node.js processes to kill"'
            }
            
            // Publication des résultats Robot Framework
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
            
            // Archiver les artefacts
            archiveArtifacts artifacts: 'robot-tests/**/*.{xml,html,log,png,jpg}', fingerprint: true
        }
        
        success {
            echo '✅ Pipeline terminé avec succès.'
        }
        
        failure {
            echo '❌ Pipeline échoué.'
        }
    }
}
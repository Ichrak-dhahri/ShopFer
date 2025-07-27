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
                                              hello.robot
                '''
            }
        }
    }
    
    post {
        always {
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
pipeline {
    agent any
    
    environment {
        // Set Node.js path if needed
        PATH = "${env.PATH};C:\\Program Files\\nodejs"
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
        
        stage('Build Angular App') {
            steps {
                bat 'call npm run build'
            }
        }
        
        stage('Start Angular Dev Server') {
            steps {
                script {
                    // Start Angular dev server in background
                    bat 'start /B npm run serve'
                    // Wait for server to start
                    sleep 30
                }
            }
        }
        
        stage('Setup Robot Framework Environment') {
            steps {
                script {
                    try {
                        // Create virtual environment in robot-tests directory
                        bat '''
                            cd robot-tests
                            if exist robot_env rmdir /s /q robot_env
                            python -m venv robot_env
                        '''
                        
                        // Install specific pip version to avoid compatibility issues
                        bat '''
                            cd robot-tests
                            robot_env\\Scripts\\python -m pip install --force-reinstall pip==24.0
                        '''
                        
                        // Install Robot Framework and dependencies
                        bat '''
                            cd robot-tests
                            robot_env\\Scripts\\pip install robotframework==6.1.1
                            robot_env\\Scripts\\pip install robotframework-seleniumlibrary==6.2.0
                            robot_env\\Scripts\\pip install selenium==4.15.2
                            robot_env\\Scripts\\pip install webdriver-manager==4.0.1
                        '''
                        
                        // Download and setup WebDriver
                        bat '''
                            cd robot-tests
                            robot_env\\Scripts\\python -c "from webdriver_manager.firefox import GeckoDriverManager; from webdriver_manager.chrome import ChromeDriverManager; GeckoDriverManager().install(); ChromeDriverManager().install()"
                        '''
                    } catch (Exception e) {
                        echo "Error in Robot Framework setup: ${e.getMessage()}"
                        throw e
                    }
                }
            }
        }
        
        stage('Run Robot Framework tests') {
            steps {
                script {
                    try {
                        // Run Robot Framework tests with proper configuration
                        bat '''
                            cd robot-tests
                            robot_env\\Scripts\\robot ^
                                --outputdir results ^
                                --variable BROWSER:headlessfirefox ^
                                --variable BASE_URL:http://localhost:4200 ^
                                --variable TIMEOUT:30s ^
                                --loglevel INFO ^
                                --report report.html ^
                                --log log.html ^
                                --output output.xml ^
                                hello.robot
                        '''
                    } catch (Exception e) {
                        echo "Robot Framework tests failed: ${e.getMessage()}"
                        // Continue to post actions to capture results
                        currentBuild.result = 'UNSTABLE'
                    }
                }
            }
        }
    }
    
    post {
        always {
            script {
                try {
                    // Stop Angular dev server
                    bat 'taskkill /F /IM node.exe /T || exit 0'
                } catch (Exception e) {
                    echo "Could not stop Angular dev server: ${e.getMessage()}"
                }
            }
            
            // Publication des résultats Robot Framework
            script {
                try {
                    robot(
                        outputPath: 'robot-tests/results',
                        outputFileName: 'output.xml',
                        reportFileName: 'report.html',
                        logFileName: 'log.html',
                        disableArchiveOutput: false,
                        passThreshold: 80,
                        unstableThreshold: 60,
                        otherFiles: '*.png,*.jpg'
                    )
                } catch (Exception e) {
                    echo "Could not publish Robot Framework results: ${e.getMessage()}"
                }
            }
            
            // Archive artifacts with error handling
            script {
                try {
                    archiveArtifacts artifacts: 'robot-tests/results/**/*.{xml,html,log,png,jpg}', 
                                   allowEmptyArchive: true, 
                                   fingerprint: true
                } catch (Exception e) {
                    echo "Could not archive artifacts: ${e.getMessage()}"
                }
            }
        }
        
        success {
            echo '✅ Pipeline terminé avec succès.'
        }
        
        failure {
            echo '❌ Pipeline échoué.'
        }
        
        unstable {
            echo '⚠️ Pipeline instable - certains tests ont échoué.'
        }
    }
}
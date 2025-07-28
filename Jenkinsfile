pipeline {
    agent any
    
    environment {
        NODE_PATH = "${env.PATH};C:\\Program Files\\nodejs"
        DISPLAY = ':99' // For headless browsers
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
                    // Kill any existing node processes
                    bat 'taskkill /F /IM node.exe /T || exit 0'
                    
                    // Start Angular dev server in background
                    bat '''
                        start /B cmd /c "npm start > server.log 2>&1"
                    '''
                    
                    // Wait for server to start and verify it's running
                    echo "Waiting for Angular dev server to start..."
                    sleep 15
                    
                    // Test if server is responding
                    script {
                        def serverRunning = false
                        for(int i = 0; i < 10; i++) {
                            try {
                                def response = bat(
                                    script: 'curl -s -o nul -w "%{http_code}" http://localhost:4200',
                                    returnStdout: true
                                ).trim()
                                if(response == '200') {
                                    serverRunning = true
                                    echo "✅ Angular server is running and responding"
                                    break
                                }
                            } catch(Exception e) {
                                echo "Server not ready yet, attempt ${i+1}/10"
                            }
                            sleep 3
                        }
                        
                        if(!serverRunning) {
                            // Try alternative check
                            bat 'netstat -an | findstr :4200 || echo "Port 4200 not found"'
                            bat 'type server.log || echo "No server log found"'
                            error "Angular dev server failed to start properly"
                        }
                    }
                }
            }
        }
        
        stage('Setup Robot Framework Environment') {
            steps {
                script {
                    try {
                        // Clean up any existing environment
                        bat '''
                            cd robot-tests
                            if exist robot_env rmdir /s /q robot_env
                            if exist results rmdir /s /q results
                            mkdir results
                        '''
                        
                        // Create fresh virtual environment
                        bat '''
                            cd robot-tests
                            python -m venv robot_env
                        '''
                        
                        // Upgrade pip to a stable version
                        bat '''
                            cd robot-tests
                            robot_env\\Scripts\\python -m pip install --upgrade pip==24.0
                        '''
                        
                        // Install Robot Framework and dependencies with specific versions
                        bat '''
                            cd robot-tests
                            robot_env\\Scripts\\pip install robotframework==7.0
                            robot_env\\Scripts\\pip install robotframework-seleniumlibrary==6.6.1
                            robot_env\\Scripts\\pip install selenium==4.15.2
                            robot_env\\Scripts\\pip install webdriver-manager==4.0.1
                        '''
                        
                        // Verify installations
                        bat '''
                            cd robot-tests
                            robot_env\\Scripts\\robot --version
                            robot_env\\Scripts\\python -c "import SeleniumLibrary; print('SeleniumLibrary imported successfully')"
                            robot_env\\Scripts\\python -c "import selenium; print(f'Selenium version: {selenium.__version__}')"
                        '''
                        
                        // Setup WebDrivers
                        bat '''
                            cd robot-tests
                            robot_env\\Scripts\\python -c "
from webdriver_manager.firefox import GeckoDriverManager
from webdriver_manager.chrome import ChromeDriverManager
try:
    gecko_path = GeckoDriverManager().install()
    print(f'GeckoDriver installed at: {gecko_path}')
    chrome_path = ChromeDriverManager().install()
    print(f'ChromeDriver installed at: {chrome_path}')
except Exception as e:
    print(f'WebDriver setup error: {e}')
"
                        '''
                        
                    } catch (Exception e) {
                        echo "Error in Robot Framework setup: ${e.getMessage()}"
                        // Log more details for debugging
                        bat '''
                            python --version
                            where python
                            pip --version
                        '''
                        throw e
                    }
                }
            }
        }
        
        stage('Run Robot Framework tests') {
            steps {
                script {
                    try {
                        // First, test basic connectivity
                        bat '''
                            curl -I http://localhost:4200 || echo "Curl test failed"
                        '''
                        
                        // Run Robot Framework tests with verbose logging
                        bat '''
                            cd robot-tests
                            robot_env\\Scripts\\robot ^
                                --outputdir results ^
                                --variable BROWSER:headlessfirefox ^
                                --variable BASE_URL:http://localhost:4200 ^
                                --variable TIMEOUT:30s ^
                                --loglevel DEBUG ^
                                --report report.html ^
                                --log log.html ^
                                --output output.xml ^
                                --debugfile debug.log ^
                                --listener "robot_listeners.py" ^
                                hello.robot
                        '''
                    } catch (Exception e) {
                        echo "Robot Framework tests encountered issues: ${e.getMessage()}"
                        
                        // Capture debug information
                        bat '''
                            cd robot-tests
                            if exist results\\debug.log type results\\debug.log
                            if exist results\\log.html echo "Log file created"
                            dir results
                        '''
                        
                        // Mark as unstable instead of failing to see results
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
                    bat 'taskkill /F /IM chrome.exe /T || exit 0'
                    bat 'taskkill /F /IM firefox.exe /T || exit 0'
                } catch (Exception e) {
                    echo "Cleanup warning: ${e.getMessage()}"
                }
            }
            
            // Publish Robot Framework results with error handling
            script {
                try {
                    robot(
                        outputPath: 'robot-tests/results',
                        outputFileName: 'output.xml',
                        reportFileName: 'report.html',
                        logFileName: 'log.html',
                        disableArchiveOutput: false,
                        passThreshold: 50.0,
                        unstableThreshold: 30.0,
                        otherFiles: '*.png,*.jpg,*.log'
                    )
                } catch (Exception e) {
                    echo "Could not publish Robot Framework results: ${e.getMessage()}"
                    // Try to find and display what files were created
                    bat '''
                        cd robot-tests
                        dir /s *.xml *.html *.log || echo "No result files found"
                    '''
                }
            }
            
            // Archive artifacts
            script {
                try {
                    archiveArtifacts artifacts: 'robot-tests/results/**/*,robot-tests/*.log,server.log', 
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
            // Print debug information
            bat '''
                echo "=== DEBUG INFORMATION ==="
                netstat -an | findstr :4200
                tasklist | findstr node.exe
                cd robot-tests && dir /s
            '''
        }
        
        unstable {
            echo '⚠️ Pipeline instable - certains tests ont échoué mais les résultats sont disponibles.'
        }
    }
}
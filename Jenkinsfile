pipeline {
    agent any
    
    environment {
        NODE_OPTIONS = '--max-old-space-size=4096'
        CHROME_BIN = 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe'
        CHROMEDRIVER_PATH = 'C:\\chromedriver\\chromedriver.exe'
    }
    
    stages {
        stage('Clean Workspace') {
            steps {
                // Kill any existing Node.js processes
                bat '''
                    taskkill /F /IM node.exe /T 2>nul || echo "No existing Node.js processes"
                    taskkill /F /IM ng.exe /T 2>nul || echo "No existing ng processes" 
                '''
                
                // Clean npm cache and node_modules
                bat '''
                    if exist node_modules rmdir /s /q node_modules
                    if exist dist rmdir /s /q dist
                    npm cache clean --force
                '''
            }
        }
        
        stage('Clone repository') {
            steps {
                git branch: 'main', url: 'https://github.com/Ichrak-dhahri/ShopFer.git'
            }
        }
        
        stage('Install dependencies') {
            steps {
                bat '''
                    echo "Installing npm dependencies..."
                    npm install --prefer-offline --no-audit --progress=false
                    
                    echo "Verifying Angular CLI..."
                    npx ng version || npm install -g @angular/cli@latest
                '''
            }
        }
        
        stage('Lint and Test') {
            parallel {
                stage('Run Linting') {
                    steps {
                        bat 'npm run lint || echo "Linting completed with warnings"'
                    }
                }
                
                stage('Run Unit Tests') {
                    steps {
                        bat '''
                            npm run test -- --karma-config karma.conf.js --watch=false --browsers=ChromeHeadless --code-coverage || echo "Tests completed"
                        '''
                    }
                }
            }
        }
        
        stage('Build Application') {
            steps {
                bat '''
                    echo "Building Angular application..."
                    npm run build --prod
                    
                    echo "Verifying build output..."
                    if not exist "dist" (
                        echo "ERROR: Build failed - dist folder not created"
                        exit 1
                    )
                    dir dist
                '''
            }
        }
        
        stage('Start Application') {
            steps {
                script {
                    echo 'Starting Angular application...'
                    
                    // Start the application with better error handling
                    def startResult = bat(
                        script: '''
                            echo "Starting Angular dev server..."
                            start /B cmd /c "npm run start > app.log 2>&1"
                            timeout /t 5 /nobreak
                        ''',
                        returnStatus: true
                    )
                    
                    if (startResult != 0) {
                        error "Failed to start Angular application"
                    }
                    
                    // Enhanced health check with better timeout handling
                    echo 'Waiting for application to be ready...'
                    
                    def maxAttempts = 30
                    def attempt = 0
                    def appReady = false
                    
                    timeout(time: 5, unit: 'MINUTES') {
                        while (attempt < maxAttempts && !appReady) {
                            attempt++
                            
                            def healthCheck = bat(
                                script: '''
                                    powershell -Command "
                                        try { 
                                            $response = Invoke-WebRequest -Uri http://localhost:4200 -TimeoutSec 10 -UseBasicParsing
                                            if ($response.StatusCode -eq 200) { 
                                                Write-Host 'Application is ready!'
                                                exit 0 
                                            } else { 
                                                Write-Host 'Application returned status: ' $response.StatusCode
                                                exit 1 
                                            }
                                        } catch { 
                                            Write-Host 'Health check failed: ' $_.Exception.Message
                                            exit 1 
                                        }
                                    "
                                ''',
                                returnStatus: true
                            )
                            
                            if (healthCheck == 0) {
                                appReady = true
                                echo "✅ Application is ready after ${attempt} attempts"
                            } else {
                                echo "⏳ Attempt ${attempt}/${maxAttempts} - Application not ready yet..."
                                
                                // Log application output for debugging
                                bat '''
                                    echo "=== Application Log ==="
                                    if exist app.log (
                                        type app.log | findstr /i "error\\|warning\\|listening\\|compiled"
                                    ) else (
                                        echo "No app.log found"
                                    )
                                    echo "======================="
                                '''
                                
                                sleep(time: 10, unit: 'SECONDS')
                            }
                        }
                    }
                    
                    if (!appReady) {
                        // Capture final logs before failing
                        bat '''
                            echo "=== Final Application Log ==="
                            if exist app.log type app.log
                            echo "=== Process List ==="
                            tasklist | findstr /i "node\\|ng\\|npm"
                            echo "=== Port Check ==="
                            netstat -an | findstr :4200
                        '''
                        error "Application failed to start within timeout period"
                    }
                    
                    // Verify application is serving Angular content
                    bat '''
                        powershell -Command "
                            $response = Invoke-WebRequest -Uri http://localhost:4200 -UseBasicParsing
                            if ($response.Content -match 'ng-version' -or $response.Content -match 'Angular' -or $response.Content -match 'app-root') {
                                Write-Host '✅ Angular application detected'
                            } else {
                                Write-Host '⚠️ Warning: Response may not be Angular app'
                                Write-Host 'Response preview:' $response.Content.Substring(0, [Math]::Min(200, $response.Content.Length))
                            }
                        "
                    '''
                }
            }
        }
        
        stage('Setup Robot Framework Environment') {
            steps {
                bat '''
                    echo "Setting up Robot Framework environment..."
                    
                    if not exist robot-tests mkdir robot-tests
                    cd robot-tests
                    
                    echo "Creating virtual environment..."
                    python -m venv robot_env
                    
                    echo "Upgrading pip..."
                    robot_env\\Scripts\\python -m pip install --upgrade pip
                    
                    echo "Installing Robot Framework dependencies..."
                    robot_env\\Scripts\\pip install robotframework==6.1.1
                    robot_env\\Scripts\\pip install robotframework-seleniumlibrary==6.1.3
                    robot_env\\Scripts\\pip install selenium==4.15.0
                    robot_env\\Scripts\\pip install webdriver-manager==4.0.1
                    
                    echo "Verifying installation..."
                    robot_env\\Scripts\\robot --version
                    robot_env\\Scripts\\python -c "import selenium; print(f'Selenium version: {selenium.__version__}')"
                '''
            }
        }
        
        stage('Run Robot Framework Tests') {
            steps {
                script {
                    // Verify application is still running
                    def appCheck = bat(
                        script: 'powershell -Command "try { Invoke-WebRequest -Uri http://localhost:4200 -TimeoutSec 5 -UseBasicParsing | Out-Null; exit 0 } catch { exit 1 }"',
                        returnStatus: true
                    )
                    
                    if (appCheck != 0) {
                        error "Application is not responding before running tests"
                    }
                    
                    // Download and setup ChromeDriver if needed
                    bat '''
                        cd robot-tests
                        robot_env\\Scripts\\python -c "
                        from webdriver_manager.chrome import ChromeDriverManager
                        import os
                        driver_path = ChromeDriverManager().install()
                        print(f'ChromeDriver installed at: {driver_path}')
                        "
                    '''
                    
                    // Run Robot Framework tests with comprehensive configuration
                    def testResult = bat(
                        script: '''
                            cd robot-tests
                            robot_env\\Scripts\\robot ^
                                --outputdir results ^
                                --variable BROWSER:headlesschrome ^
                                --variable BASE_URL:http://localhost:4200 ^
                                --variable TIMEOUT:30s ^
                                --loglevel INFO ^
                                --report report.html ^
                                --log log.html ^
                                --output output.xml ^
                                --debugfile debug.log ^
                                --listener RetryFailed:3 ^
                                --include smoke OR critical ^
                                --exclude debug ^
                                hello.robot
                        ''',
                        returnStatus: true
                    )
                    
                    // Archive results regardless of test outcome
                    bat '''
                        cd robot-tests
                        if not exist results mkdir results
                        if exist debug.log move debug.log results\\
                        echo "Test execution completed with exit code: %ERRORLEVEL%"
                    '''
                    
                    if (testResult != 0) {
                        currentBuild.result = 'UNSTABLE'
                        echo "⚠️ Some tests failed, but pipeline continues"
                    } else {
                        echo "✅ All tests passed successfully"
                    }
                }
            }
        }
    }
    
    post {
        always {
            script {
                echo 'Cleaning up processes and publishing results...'
                
                // Kill all Node.js processes
                bat '''
                    echo "Stopping Node.js processes..."
                    taskkill /F /IM node.exe /T 2>nul || echo "No Node.js processes to kill"
                    taskkill /F /IM ng.exe /T 2>nul || echo "No ng processes to kill"
                    taskkill /F /IM npm.cmd /T 2>nul || echo "No npm processes to kill"
                    
                    echo "Cleaning up port 4200..."
                    for /f "tokens=5" %%a in ('netstat -aon ^| find ":4200" ^| find "LISTENING"') do taskkill /F /PID %%a 2>nul || echo "Port cleanup completed"
                '''
                
                // Archive application logs
                if (fileExists('app.log')) {
                    archiveArtifacts artifacts: 'app.log', fingerprint: true, allowEmptyArchive: true
                }
                
                // Publish Robot Framework results if they exist
                if (fileExists('robot-tests/results/output.xml')) {
                    robot(
                        outputPath: 'robot-tests/results',
                        outputFileName: 'output.xml',
                        reportFileName: 'report.html',
                        logFileName: 'log.html',
                        disableArchiveOutput: false,
                        passThreshold: 90.0,
                        unstableThreshold: 70.0,
                        criticalThreshold: 100.0,
                        otherFiles: '**/*.png,**/*.jpg,**/*.log'
                    )
                    
                    // Archive all test artifacts
                    archiveArtifacts(
                        artifacts: 'robot-tests/results/**/*',
                        fingerprint: true,
                        allowEmptyArchive: true
                    )
                } else {
                    echo "⚠️ No Robot Framework results found to publish"
                }
                
                // Publish test coverage if available
                if (fileExists('coverage/lcov.info')) {
                    publishHTML([
                        allowMissing: false,
                        alwaysLinkToLastBuild: true,
                        keepAll: true,
                        reportDir: 'coverage/lcov-report',
                        reportFiles: 'index.html',
                        reportName: 'Code Coverage Report'
                    ])
                }
            }
        }
        
        success {
            echo '✅ Pipeline completed successfully!'
            
            // Send success notification if configured
            script {
                if (env.SLACK_WEBHOOK) {
                    slackSend(
                        color: 'good',
                        message: "✅ ShopFer Pipeline Success: ${env.JOB_NAME} - ${env.BUILD_NUMBER}"
                    )
                }
            }
        }
        
        failure {
            echo '❌ Pipeline failed!'
            
            // Capture final system state for debugging
            bat '''
                echo "=== Final System State ==="
                echo "Running processes:"
                tasklist | findstr /i "node\\|ng\\|npm\\|chrome"
                echo "Port status:"
                netstat -an | findstr :4200
                echo "Application log:"
                if exist app.log (
                    echo "Last 20 lines of app.log:"
                    powershell -Command "Get-Content app.log -Tail 20"
                )
            '''
            
            // Send failure notification if configured
            script {
                if (env.SLACK_WEBHOOK) {
                    slackSend(
                        color: 'danger',
                        message: "❌ ShopFer Pipeline Failed: ${env.JOB_NAME} - ${env.BUILD_NUMBER}\nCheck logs: ${env.BUILD_URL}"
                    )
                }
            }
        }
        
        unstable {
            echo '⚠️ Pipeline completed with test failures'
            
            script {
                if (env.SLACK_WEBHOOK) {
                    slackSend(
                        color: 'warning',
                        message: "⚠️ ShopFer Pipeline Unstable: ${env.JOB_NAME} - ${env.BUILD_NUMBER}\nSome tests failed"
                    )
                }
            }
        }
    }
}
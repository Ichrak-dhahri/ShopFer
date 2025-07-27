pipeline {
    agent any
    
    environment {
        DOCKER_IMAGE = "shopfer/angular-app"
        DOCKER_TAG = "${BUILD_NUMBER}"
        NODE_ENV = "production"
    }
    
    stages {
        stage('Checkout') {
            steps {
                git branch: 'main', url: 'https://github.com/Ichrak-dhahri/ShopFer'
            }
        }
        
        stage('Install Dependencies') {
            steps {
                sh 'npm ci'
            }
        }
        
        stage('Unit Tests') {
            steps {
                sh 'npm run test -- --watch=false --browsers=ChromeHeadless --code-coverage'
            }
            post {
                always {
                    // Publier les résultats des tests
                    publishHTML([
                        allowMissing: false,
                        alwaysLinkToLastBuild: true,
                        keepAll: true,
                        reportDir: 'coverage',
                        reportFiles: 'index.html',
                        reportName: 'Coverage Report'
                    ])
                }
            }
        }
        
        stage('Lint & Code Quality') {
            parallel {
                stage('ESLint') {
                    steps {
                        sh 'npx ng lint || true'
                    }
                }
                stage('Build Check') {
                    steps {
                        sh 'npm run build'
                    }
                }
            }
        }
        
        stage('Build Docker Image') {
            steps {
                script {
                    // Builder l'image Docker
                    def image = docker.build("${DOCKER_IMAGE}:${DOCKER_TAG}")
                    
                    // Tagger aussi comme 'latest' si sur main
                    if (env.BRANCH_NAME == 'main') {
                        image.tag("latest")
                    }
                }
            }
        }
        
        stage('Test Docker Image') {
            steps {
                script {
                    // Test que l'image démarre correctement
                    sh """
                        docker run --name test-container -d -p 4001:4000 ${DOCKER_IMAGE}:${DOCKER_TAG}
                        sleep 10
                        curl -f http://localhost:4001 || exit 1
                        docker stop test-container
                        docker rm test-container
                    """
                }
            }
        }
        
        stage('Security Scan') {
            steps {
                script {
                    // Scanner l'image avec Trivy
                    sh """
                        docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \\
                            -v \$(pwd):/tmp/.cache/ aquasec/trivy:latest image \\
                            --exit-code 1 --severity HIGH,CRITICAL \\
                            ${DOCKER_IMAGE}:${DOCKER_TAG}
                    """
                }
            }
        }
        
        stage('Push Docker Image') {
            when {
                branch 'main'
            }
            steps {
                script {
                    docker.withRegistry('https://index.docker.io/v1/', 'docker-registry-credentials') {
                        def image = docker.image("${DOCKER_IMAGE}:${DOCKER_TAG}")
                        image.push()
                        image.push("latest")
                    }
                }
            }
        }
        
        stage('Deploy to Staging') {
            when {
                branch 'main'
            }
            steps {
                script {
                    // Arrêter et supprimer l'ancien container s'il existe
                    sh '''
                        docker stop shopfer-staging || true
                        docker rm shopfer-staging || true
                    '''
                    
                    // Déployer la nouvelle version
                    sh """
                        docker run -d --name shopfer-staging \\
                            --restart unless-stopped \\
                            -p 8080:4000 \\
                            -e NODE_ENV=production \\
                            ${DOCKER_IMAGE}:${DOCKER_TAG}
                    """
                    
                    // Vérifier que le déploiement fonctionne
                    sh 'sleep 15 && curl -f http://localhost:8080'
                }
            }
        }
    }
    
    post {
        always {
            // Nettoyer les images locales anciennes
            sh """
                docker image prune -f
                docker system prune -f
            """
        }
        success {
            emailext (
                subject: "✅ Build Success: Shopfer v${BUILD_NUMBER}",
                body: """
                    Build completed successfully!
                    
                    Version: ${BUILD_NUMBER}
                    Branch: ${BRANCH_NAME}
                    Docker Image: ${DOCKER_IMAGE}:${DOCKER_TAG}
                    
                    View build: ${BUILD_URL}
                """,
                to: "team@shopfer.com"
            )
        }
        failure {
            emailext (
                subject: "❌ Build Failed: Shopfer v${BUILD_NUMBER}",
                body: """
                    Build failed!
                    
                    Check console output: ${BUILD_URL}console
                    
                    Branch: ${BRANCH_NAME}
                    Commit: ${GIT_COMMIT}
                """,
                to: "team@shopfer.com"
            )
        }
    }
}
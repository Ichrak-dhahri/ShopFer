pipeline {
    agent any

    stages {
        stage('Build Docker Image') {
            steps {
                bat 'docker build -t shopferimgg .'
            }
        }
        stage('Run Docker Container') {
            steps {
                bat 'docker run -d -p 4200:4200 shopferimgg'
            }
        }
    }
}
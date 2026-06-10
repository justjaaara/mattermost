pipeline {
    agent any
    
    environment {
        SONAR_HOST_URL = 'http://sonarqube:9000'
        SONAR_TOKEN = 'sqp_40de1517ed87a9052364e7b1d3a78f1b1fa7d1cf'
        DOCKER_IMAGE = 'mattermost-toggle-reviewer'
    }
    
    stages {
        stage('Checkout') {
            steps {
                sh '''
                    # Clone repository from GitHub
                    git clone https://github.com/justjaaara/mattermost.git /workspace/mattermost || true
                    cd /workspace/mattermost
                    git log --oneline -5
                '''
            }
        }
        
        stage('Build Server') {
            steps {
                dir('/workspace/server') {
                    sh 'docker run --rm -v /workspace:/app -w /app/server golang:1.22-bookworm bash -c "apt-get update && apt-get install -y make && make modules-tidy && make generated"'
                }
            }
        }
        
        stage('Unit Tests') {
            steps {
                dir('/workspace/server') {
                    sh 'docker run --rm -v /workspace:/app -w /app/server golang:1.22-bookworm bash -c "apt-get update && apt-get install -y make && make modules-tidy && make generated && go test ./channels/app -run TestContentFlagging -v -coverprofile=coverage_app.out -timeout 10m && go test ./public/model -run TestContentFlagging -v -coverprofile=coverage_model.out -timeout 10m"'
                }
            }
        }
        
        stage('Coverage Report') {
            steps {
                dir('/workspace/server') {
                    sh '''
                        tail -n +2 coverage_model.out >> coverage_app.out 2>/dev/null || true
                        sed -i "s|github.com/mattermost/mattermost/server/v8/|server/|g" coverage_app.out
                        sed -i "s|github.com/mattermost/mattermost/server/public/|server/public/|g" coverage_app.out
                        go tool cover -func=coverage_app.out | grep content_flagging || true
                    '''
                }
            }
        }
        
        stage('SonarQube Analysis') {
            steps {
                dir('/workspace') {
                    sh '''
                        docker run --rm --network host \
                          -v $(pwd):/usr/src \
                          -e SONAR_HOST_URL="http://localhost:9012" \
                          sonarsource/sonar-scanner-cli
                    '''
                }
            }
        }
        
        stage('Quality Gate') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    script {
                        def qgStatus = sh(
                            script: '''
                                curl -s -u "sqp_40de1517ed87a9052364e7b1d3a78f1b1fa7d1cf:" \
                                  "http://localhost:9012/api/qualitygates/project_status?projectKey=mattermost-toggle-reviewer" | \
                                  grep -o '"status":"[^"]*"' | cut -d'"' -f4
                            ''',
                            returnStdout: true
                        ).trim()
                        
                        if (qgStatus != "OK" && qgStatus != "PASSED") {
                            echo "Quality Gate failed with status: ${qgStatus}"
                        } else {
                            echo "Quality Gate passed: ${qgStatus}"
                        }
                    }
                }
            }
        }
        
        stage('Docker Build') {
            steps {
                dir('/workspace') {
                    sh 'docker build -t ${DOCKER_IMAGE}:${BUILD_NUMBER} .'
                    sh 'docker tag ${DOCKER_IMAGE}:${BUILD_NUMBER} ${DOCKER_IMAGE}:latest'
                }
            }
        }
        
        stage('Deploy') {
            steps {
                echo "Deploying ${DOCKER_IMAGE}:${BUILD_NUMBER}"
                echo "Deployment step for demonstration purposes"
            }
        }
    }
    
    post {
        always {
            archiveArtifacts artifacts: 'server/coverage_app.out', allowEmptyArchive: true
        }
        success {
            echo 'Pipeline completed successfully'
        }
        failure {
            echo 'Pipeline failed'
        }
    }
}

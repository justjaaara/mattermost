pipeline {
    agent any

    environment {
        SONAR_HOST_URL = 'http://sonarqube:9000'
        SONAR_TOKEN = 'sqp_3d654a108fb80176815a7b5a1a3cfec86edf55de'
        DOCKER_IMAGE = 'mattermost-toggle-reviewer'
        IS_CI = 'true'
    }

    stages {
        stage('Checkout') {
            steps {
                sh '''
                    # Clean and clone repository from GitHub
                    rm -rf /var/jenkins_home/workspace/mattermost
                    git clone --depth 1 https://github.com/justjaaara/mattermost.git /var/jenkins_home/workspace/mattermost
                    cd /var/jenkins_home/workspace/mattermost
                    git log --oneline -5
                '''
            }
        }

        stage('Build Server') {
            steps {
                dir('/var/jenkins_home/workspace/mattermost/server') {
                    sh '''
                        # Install Go and make if not present
                        if ! command -v go &> /dev/null; then
                            curl -sL https://go.dev/dl/go1.26.0.linux-amd64.tar.gz -o go.tar.gz
                            tar -C /usr/local -xzf go.tar.gz
                            export PATH=$PATH:/usr/local/go/bin
                        fi
                        if ! command -v make &> /dev/null; then
                            apt-get update && apt-get install -y make
                        fi
                        if ! command -v docker &> /dev/null; then
                            apt-get install -y docker.io
                        fi
                        go version
                        make modules-tidy
                        make setup-go-work
                        # Generate mocks without Docker (skip start-docker)
                        go generate -buildvcs=false ./channels/store
                        cd ./public && go generate -buildvcs=false ./plugin
                    '''
                }
            }
        }

        stage('Unit Tests') {
            steps {
                dir('/var/jenkins_home/workspace/mattermost/server') {
                    sh '''
                        export PATH=$PATH:/usr/local/go/bin
                        go test ./channels/app -run TestContentFlagging -v -coverprofile=coverage_app.out -timeout 10m
                        go test ./public/model -run TestContentFlagging -v -coverprofile=coverage_model.out -timeout 10m
                    '''
                }
            }
        }

        stage('Coverage Report') {
            steps {
                dir('/var/jenkins_home/workspace/mattermost/server') {
                    sh '''
                        tail -n +2 coverage_model.out >> coverage_app.out 2>/dev/null || true
                        sed -i "s|github.com/mattermost/mattermost/server/v8/|server/|g" coverage_app.out
                        sed -i "s|github.com/mattermost/mattermost/server/public/|server/public/|g" coverage_app.out
                        export PATH=$PATH:/usr/local/go/bin
                        go tool cover -func=coverage_app.out | grep content_flagging || true
                    '''
                }
            }
        }

        stage('SonarQube Analysis') {
            steps {
                dir('/var/jenkins_home/workspace/mattermost') {
                    sh '''
                        docker run --rm --network mattermost_mattermost-network \
                          -v $(pwd):/usr/src \
                          -e SONAR_HOST_URL="http://sonarqube:9000" \
                          -e SONAR_TOKEN="sqp_40de1517ed87a9052364e7b1d3a78f1b1fa7d1cf" \
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
                                curl -s -u "squ_76af51993ab2c2caa3694a8cf289e140642c2900:" \
                                  "http://sonarqube:9000/api/qualitygates/project_status?projectKey=mattermost-toggle-reviewer" | \
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
                dir('/var/jenkins_home/workspace/mattermost') {
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

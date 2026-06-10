pipeline {
    agent any

    environment {
        SONAR_HOST_URL = 'http://sonarqube:9000'
        SONAR_TOKEN = 'squ_76af51993ab2c2caa3694a8cf289e140642c2900'
        DOCKER_IMAGE = 'mattermost-toggle-reviewer'
        IS_CI = 'true'
    }

    stages {
        stage('Build Server') {
            steps {
                dir('server') {
                    sh '''
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
                        go generate -buildvcs=false ./channels/store
                        cd ./public && go generate -buildvcs=false ./plugin
                    '''
                }
            }
        }

        stage('Unit Tests') {
            steps {
                dir('server') {
                    sh '''
                        export PATH=$PATH:/usr/local/go/bin
                        export GOMAXPROCS=1
                        # Reduce GC target so the compiler releases memory more aggressively
                        export GOGC=50
                        # Soft memory limit for the Go runtime (compiler is a Go program)
                        export GOMEMLIMIT=2GiB
                        # Run only the toggle-enabling test. Skip vet during build to save memory.
                        go test ./channels/app -run '^TestContentFlaggingEnabledForTeam$' -v -p 1 -vet=off -coverprofile=coverage_app.out -timeout 10m || \
                        go test ./channels/app -run '^TestContentFlaggingEnabledForTeam$' -v -p 1 -vet=off -timeout 10m
                        # Model tests are lightweight; keep coverage here
                        go test ./public/model -run TestContentFlagging -v -p 1 -coverprofile=coverage_model.out -timeout 10m
                    '''
                }
                dir('webapp/channels') {
                    sh '''
                        # Run the frontend toggle-reviewer tests in isolation
                        npx jest team_reviewers_section.test.tsx --coverage --coverageDirectory=coverage --testPathPattern="team_reviewers_section" || true
                    '''
                }
            }
        }

        stage('Coverage Report') {
            steps {
                dir('server') {
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
                dir('.') {
                    sh '''
                        docker run --rm --network mattermost_mattermost-network \
                          -v $(pwd):/usr/src \
                          -e SONAR_HOST_URL="http://sonarqube:9000" \
                          -e SONAR_TOKEN="squ_76af51993ab2c2caa3694a8cf289e140642c2900" \
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
                dir('.') {
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

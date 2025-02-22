def helmDeploy(Map args) {
    sh """
        helm upgrade --install ${args.REPO_NAME}-${args.environment} ${args.HELM_CHART_PATH} \
        --namespace ${args.namespace} \
        --set image.repository=${args.AWS_ACCOUNT_ID}.dkr.ecr.${args.AWS_REGION}.amazonaws.com/${args.REPO_NAME} \
        --set image.tag=${args.TAG} \
        --values ${args.HELM_CHART_PATH}/values-${args.environment}.yaml
    """
}

pipeline {
    agent any

    tools {
        jdk 'jdk17'
        nodejs 'node23'
    }
    
    environment {
        DATE = new Date().format('yy.M')
        TAG = "${DATE}.${BUILD_NUMBER}"
        NVD_API_KEY = 'NVD-API'
        AWS_ACCOUNT_ID = '586794478801'
        AWS_REGION = 'eu-west-2'
        ECR_REPO = 'repo-url'
        REPO_NAME = 'python-flask-deployment'
        HELM_CHART_PATH = './event-booking/templates' // Path to Helm chart
        DEV_CLUSTER = 'python-cluster-dev-stag-qa'   // Shared cluster for QA/Staging
        PROD_CLUSTER = 'python-cluster-production'
    }

    stages {
        stage('Clean Workspace') {
            steps {
                cleanWs()
            }
        }

        stage('Checkout') {
            steps {
                git branch: 'development', credentialsId: 'GitHub-Token', url: 'https://github.com/lloyd-theophilus/event-booking-app.git'
            }
        }
        
        stage('Install Dependencies') {
            steps {
                script {
                    sh 'npm install'
                }
            }
        }
        
        stage('SonarQube Analysis') {
            steps {
                script {
                    scannerHome = tool 'sonar-scanner' // must match the name of an actual scanner installation directory on your Jenkins build agent
                }
                withSonarQubeEnv('sonar-server') {
                    sh "${scannerHome}/bin/sonar-scanner \
                       -Dsonar.projectKey=Event-Booking \
                       -Dsonar.sources=. \
                       -Dsonar.host.url=https://sonaqube.kellerbeam.com"
                }
            }
        }
        
        /* Uncomment if needed
        stage('Quality Gate') {
            steps {
                script {
                    waitForQualityGate abortPipeline: false, credentialsId: 'Sonar-token'
                }
            }
        }
        */
        
        stage('OWASP FS Scan') {
            steps {
                dependencyCheck additionalArguments: '--scan ./ --disableYarnAudit --disableNodeAudit',
                 odcInstallation: 'DP-CHECK'
                dependencyCheckPublisher pattern: '**/dependency-check-report.xml'
            }
        }
        
        stage('Build Image') {
            when { 
                anyOf {
                    branch 'QA'
                    branch 'staging'
                    branch 'production'
                }
            }
            steps {
                script {
                    sh "docker build -t ${REPO_NAME}:${TAG} ."
                }
            }
        }
        
        stage('Scan Image') {
            when { 
                anyOf {
                    branch 'QA'
                    branch 'staging'
                    branch 'production'
                }
            }
            steps {
                script {
                    sh "trivy image --exit-code 0 --format table ${REPO_NAME}:${TAG} > trivy-image-scan.txt"
                }
            }
        }

        stage('Push to ECR') {
            when { 
                anyOf {
                    branch 'QA'
                    branch 'staging'
                    branch 'production'
                }
            }
            steps {
                script {
                    sh "aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
                    sh "docker tag ${REPO_NAME}:${TAG} ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${REPO_NAME}:${TAG}"
                    sh "docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${REPO_NAME}:${TAG}"
                }
            }
        }

        stage('Deploy to QA') {
            when { branch 'QA' }
            steps {
                script {
                    sh "aws eks update-kubeconfig --name ${DEV_CLUSTER} --region ${AWS_REGION}"
                    helmDeploy(
                        namespace: "qa",
                        environment: "qa",
                        REPO_NAME: "${REPO_NAME}",
                        HELM_CHART_PATH: "${HELM_CHART_PATH}",
                        AWS_ACCOUNT_ID: "${AWS_ACCOUNT_ID}",
                        AWS_REGION: "${AWS_REGION}",
                        TAG: "${TAG}"
                    )
                }
            }
        }

        stage('Deploy to Staging') {
            when { branch 'staging' }
            steps {
                script {
                    sh "aws eks update-kubeconfig --name ${DEV_CLUSTER} --region ${AWS_REGION}"
                    helmDeploy(
                        namespace: "staging",
                        environment: "staging",
                        REPO_NAME: "${REPO_NAME}",
                        HELM_CHART_PATH: "${HELM_CHART_PATH}",
                        AWS_ACCOUNT_ID: "${AWS_ACCOUNT_ID}",
                        AWS_REGION: "${AWS_REGION}",
                        TAG: "${TAG}"
                    )
                }
            }
        }

        stage('Production Approval') {
            when { branch 'production' }
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    input message: "Deploy to PRODUCTION?", ok: "Confirm"
                }
            }
        }

        stage('Deploy to Production') {
            when { branch 'production' }
            steps {
                script {
                    sh "aws eks update-kubeconfig --name ${PROD_CLUSTER} --region ${AWS_REGION}"
                    helmDeploy(
                        namespace: "production",
                        environment: "prod",
                        REPO_NAME: "${REPO_NAME}",
                        HELM_CHART_PATH: "${HELM_CHART_PATH}",
                        AWS_ACCOUNT_ID: "${AWS_ACCOUNT_ID}",
                        AWS_REGION: "${AWS_REGION}",
                        TAG: "${TAG}"
                    )
                }
            }
        }
    }
}






def helmDeploy(Map args) {
    sh """
        helm upgrade --install ${args.REPO_NAME}-${args.environment} ${args.HELM_CHART_PATH} \\
        --namespace ${args.namespace} \\
        --values ${args.HELM_CHART_PATH}/values-${args.environment}.yaml \\
        --set deployment.name=python-deployment-qa-${args.environment} \\  
        --set image.tag=${args.TAG}
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
        HELM_CHART_PATH = './event-booking' // Path to Helm chart
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
                echo "Building branch: ${env.BRANCH_NAME}"
                checkout scm
            }
        }
        
        stage('SonarQube Analysis') {
            steps {
                script {
                    scannerHome = tool 'sonar-scanner'
                }
                withSonarQubeEnv('sonar-server') {
                    sh "${scannerHome}/bin/sonar-scanner -Dsonar.projectKey=Event-Booking -Dsonar.sources=. -Dsonar.host.url=https://sonaqube.kellerbeam.com"
                }
            }
        }
        /*
            stage('Quality Gate') {

                steps {
                script {
                    waitForQualityGate abortPipeline: false, credentialsId: 'Sonar-token'
                }
                }
            } */

        stage('Determine Environment Variables') {
            // This stage runs only for branches that need to build and deploy
            when {
                anyOf {
                    branch 'testing'
                    branch 'staging'
                    branch 'production'
                }
            }
            steps {
                script {
                    // Set ECR_REPO and REPO_NAME based on the triggering branch.
                    if (env.BRANCH_NAME == 'testing') {
                        env.ECR_REPO = 'qa-ecr-repoUrl'
                        env.REPO_NAME = 'python-deplyment-qa'
                    } else if (env.BRANCH_NAME == 'staging') {
                        env.ECR_REPO = 'repo-url'
                        env.REPO_NAME = 'python-flask-deployment'
                    } else if (env.BRANCH_NAME == 'production') {
                        env.ECR_REPO = 'prod-ecrUrl'
                        env.REPO_NAME = 'python-deployment-production'
                    } else {
                        error "Unsupported branch: ${env.BRANCH_NAME}"
                    }
                    echo "Selected ECR_REPO: ${env.ECR_REPO}"
                    echo "Selected REPO_NAME: ${env.REPO_NAME}"
                }
            }
        }
        
        stage('Install Dependencies') {
            when {
                anyOf {
                    branch 'testing'
                    branch 'staging'
                    branch 'production'
                }
            }
            steps {
                sh 'npm install'
            }
        }
        
        
      //  stage('OWASP FS Scan') {
      //      steps {
      //         dependencyCheck additionalArguments: '--scan ./ --disableYarnAudit --disableNodeAudit', odcInstallation: 'DP-CHECK'
      //          dependencyCheckPublisher pattern: '**/dependency-check-report.xml'
      //      }
      //  }

        stage('Build Image') {
            when {
                anyOf {
                    branch 'testing'
                    branch 'staging'
                    branch 'production'
                }
            }
            steps {
                script {
                    // Build Docker image with dynamic REPO_NAME and TAG.
                    sh "docker build -t ${REPO_NAME}:${TAG} ."
                }
            }
        }
        
        stage('Scan Image') {
            when {
                anyOf {
                    branch 'testing'
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
                    branch 'testing'
                    branch 'staging'
                    branch 'production'
                }
            }
            steps {
                script {
                    // Authenticate to AWS ECR.
                    sh "aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
                    // Tag and push the Docker image using the dynamic REPO_NAME.
                    sh "docker tag ${REPO_NAME}:${TAG} ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${REPO_NAME}:${TAG}"
                    sh "docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${REPO_NAME}:${TAG}"
                }
            }
        }
        
        stage('Deploy to testing') {
            when { branch 'testing' }
            steps {
                script {
                    sh "aws eks update-kubeconfig --name ${DEV_CLUSTER} --region ${AWS_REGION}"
                    helmDeploy(
                        namespace: "testing",
                        environment: "testing",
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

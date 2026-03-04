pipeline {
    agent any

    environment {
        DOCKERHUB_USERNAME   = 'dinesh0793'
        IMAGE_NAME           = "${DOCKERHUB_USERNAME}/trendify"
        IMAGE_TAG            = "${BUILD_NUMBER}"
        DOCKERHUB_CREDENTIAL = 'dockerhub-credentials'            // Jenkins credential ID
        AWS_REGION           = 'ap-south-1'
        GITHUB_REPO          = 'https://github.com/Dinesh0793/Trend-proj-2.git'
        EKS_CLUSTER_NAME     = 'trendify-cluster'
        K8S_DEPLOYMENT_FILE  = 'k8s/deployment.yaml'
    }

    stages {

        stage('Checkout') {
            steps {
                echo '📥 Checking out source code...'
                checkout scm
            }
        }

        stage('Build Docker Image') {
            steps {
                echo "🐳 Building Docker image: ${IMAGE_NAME}:${IMAGE_TAG}"
                sh "docker build -t ${IMAGE_NAME}:${IMAGE_TAG} -t ${IMAGE_NAME}:latest ."
            }
        }

        stage('Push to DockerHub') {
            steps {
                echo '📤 Pushing image to DockerHub...'
                withCredentials([usernamePassword(
                    credentialsId: "${DOCKERHUB_CREDENTIAL}",
                    usernameVariable: 'DOCKER_USER',
                    passwordVariable: 'DOCKER_PASS'
                )]) {
                    sh '''
                        echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
                        docker push ${IMAGE_NAME}:${IMAGE_TAG}
                        docker push ${IMAGE_NAME}:latest
                    '''
                }
            }
        }

        stage('Update K8s Manifest') {
            steps {
                echo '✏️  Updating Kubernetes deployment image tag...'
                sh """
                    sed -i 's|image: .*trendify.*|image: ${IMAGE_NAME}:${IMAGE_TAG}|g' ${K8S_DEPLOYMENT_FILE}
                """
            }
        }

        stage('Configure kubectl for EKS') {
            steps {
                echo '🔐 Configuring kubectl for EKS cluster...'
                sh """
                    aws eks update-kubeconfig --region ${AWS_REGION} --name ${EKS_CLUSTER_NAME}
                """
            }
        }

        stage('Deploy to EKS') {
            steps {
                echo '🚀 Deploying to Kubernetes EKS...'
                sh """
                    kubectl apply -f ${K8S_DEPLOYMENT_FILE} --validate=false
                    kubectl rollout status deployment/trendify-deployment --timeout=120s
                """
            }
        }

        stage('Verify Deployment') {
            steps {
                echo '✅ Verifying deployment status...'
                sh '''
                    kubectl get pods -l app=trendify
                    kubectl get service trendify-service
                '''
            }
        }

        stage('Deploy Monitoring Stack') {
            steps {
                echo '📊 Deploying Prometheus + Grafana monitoring stack...'
                sh '''
                    kubectl apply -f k8s/monitoring/prometheus-configmap.yaml --validate=false
                    kubectl apply -f k8s/monitoring/prometheus-deployment.yaml --validate=false
                    kubectl apply -f k8s/monitoring/grafana-deployment.yaml --validate=false
                    kubectl rollout status deployment/prometheus -n monitoring --timeout=120s
                    kubectl rollout status deployment/grafana -n monitoring --timeout=120s
                    echo "✅ Monitoring stack deployed!"
                    kubectl get all -n monitoring
                '''
            }
        }
    }

    post {
        success {
            echo '🎉 Pipeline completed successfully! Trendify is deployed on EKS.'
        }
        failure {
            echo '❌ Pipeline failed. Check the logs above for details.'
        }
        always {
            echo '🧹 Cleaning up Docker images from agent...'
            sh "docker rmi ${IMAGE_NAME}:${IMAGE_TAG} || true"
            sh "docker rmi ${IMAGE_NAME}:latest || true"
        }
    }
}

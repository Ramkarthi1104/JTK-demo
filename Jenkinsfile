pipeline {
  agent any
  options { ansiColor('xterm'); timestamps() }

  environment {
    AWS_REGION      = 'ap-south-1'
    CLUSTER_NAME    = 'demo-eks'
    DOCKERHUB_REPO  = 'yourname/jenkins-terraform-k8s-demo'   // <== change me
    DOCKERHUB_CRED  = 'dockerhub'
    AWS_CREDS       = 'aws-creds'                              // remove if using IAM role
    IMAGE_TAG       = "${env.BUILD_NUMBER}"
    IMAGE_FULL      = "${env.DOCKERHUB_REPO}:${env.IMAGE_TAG}"
    TF_DIR          = 'terraform'
  }

  stages {
    stage('Checkout') {
      steps { checkout scm }
    }

    stage('Tool Versions') {
      steps {
        sh '''
          docker --version
          terraform -version
          aws --version
          kubectl version --client=true
        '''
      }
    }

    stage('Build & Push Image') {
      steps {
        withCredentials([usernamePassword(credentialsId: env.DOCKERHUB_CRED,
                                          usernameVariable: 'DH_USER',
                                          passwordVariable: 'DH_PASS')]) {
          sh '''
            cd app
            echo "$DH_PASS" | docker login -u "$DH_USER" --password-stdin
            docker build -t "$IMAGE_FULL" .
            docker push "$IMAGE_FULL"
            docker logout
          '''
        }
      }
    }

    stage('Terraform Init/Apply (EKS)') {
      steps {
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: env.AWS_CREDS]]) {
          withEnv(["AWS_DEFAULT_REGION=${env.AWS_REGION}"]) {
            dir(env.TF_DIR) {
              sh '''
                terraform init -input=false
                terraform apply -auto-approve -input=false \
                  -var="region=${AWS_DEFAULT_REGION}" \
                  -var="cluster_name=${CLUSTER_NAME}"
              '''
            }
          }
        }
      }
    }

    stage('Configure kubeconfig') {
      steps {
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: env.AWS_CREDS]]) {
          withEnv(["AWS_DEFAULT_REGION=${env.AWS_REGION}"]) {
            sh '''
              aws eks update-kubeconfig --name "${CLUSTER_NAME}" --region "${AWS_DEFAULT_REGION}"
              kubectl get nodes
            '''
          }
        }
      }
    }

    stage('Deploy to Kubernetes') {
      steps {
        sh '''
          kubectl apply -f k8s/namespace.yaml
          # Replace image placeholder on the fly and apply
          sed "s|IMAGE_PLACEHOLDER|${IMAGE_FULL}|g" k8s/deployment.yaml | kubectl apply -f -
          kubectl apply -f k8s/service.yaml
          kubectl rollout status deploy/web -n demo
          kubectl get svc -n demo
        '''
      }
    }

    stage('Smoke Test (print LB URL)') {
      steps {
        sh '''
          EXTERNAL_IP=$(kubectl get svc web-svc -n demo -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
          echo "App should be reachable at: http://${EXTERNAL_IP}"
        '''
      }
    }
  }

  post {
    failure {
      echo 'Build failed. Check logs above.'
    }
  }
}

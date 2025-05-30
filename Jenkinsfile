pipeline {
    agent any
    environment {
        AWS_REGION = 'eu-west-2'
        TF_STATE_BUCKET = "my-terraform-state-bucket-${sh(script: 'openssl rand -hex 4', returnStdout: true).trim()}"
        TF_STATE_KEY = 'terraform/state/terraform.tfstate'
        TF_LOCK_TABLE = 'terraform-state-locks'
    }
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        stage('Terraform Init') {
            steps {
                withAWS(credentials: 'access-key') {
                    sh 'terraform init -backend-config="bucket=${TF_STATE_BUCKET}" -backend-config="key=${TF_STATE_KEY}" -backend-config="region=${AWS_REGION}" -backend-config="dynamodb_table=${TF_LOCK_TABLE}"'
                }
            }
        }
        stage('Terraform Plan') {
            steps {
                withAWS(credentials: 'access-key') {
                    sh 'terraform plan -out=tfplan'
                }
            }
        }
        stage('Terraform Apply') {
            steps {
                withAWS(credentials: 'access-key') {
                    sh 'terraform apply -auto-approve tfplan'
                }
            }
        }
        stage('Terraform Destroy') {
            when {
                expression { params.ACTION == 'destroy' }
            }
            steps {
                withAWS(credentials: 'access-key') {
                    sh 'terraform destroy -auto-approve'
                }
            }
        }
    }
    post {
        always {
            cleanWs()
        }
    }
}
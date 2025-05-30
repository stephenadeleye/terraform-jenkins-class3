pipeline {
    agent any
    parameters {
        choice(name: 'ACTION', choices: ['apply', 'destroy'], description: 'Select Terraform action to perform')
    }
    environment {
        AWS_REGION = 'eu-west-2'
        TF_STATE_KEY = 'terraform/state/terraform.tfstate'
    }
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        stage('Provision State Management Resources') {
            steps {
                dir('state_management') {
                    withAWS(credentials: 'access-key') {
                        sh 'terraform init'
                        sh 'terraform apply -auto-approve'
                        // Capture outputs for bucket and table names
                        script {
                            env.TF_STATE_BUCKET = sh(script: 'terraform output -raw state_bucket_name', returnStdout: true).trim()
                            env.TF_LOCK_TABLE = sh(script: 'terraform output -raw lock_table_name', returnStdout: true).trim()
                        }
                    }
                }
            }
        }
        stage('Terraform Init') {
            steps {
                dir('main') {
                    withAWS(credentials: 'access-key') {
                        sh 'terraform init -backend-config="bucket=${TF_STATE_BUCKET}" -backend-config="key=${TF_STATE_KEY}" -backend-config="region=${AWS_REGION}" -backend-config="dynamodb_table=${TF_LOCK_TABLE}"'
                    }
                }
            }
        }
        stage('Terraform Plan') {
            when {
                expression { params.ACTION == 'apply' }
            }
            steps {
                dir('main') {
                    withAWS(credentials: 'access-key') {
                        sh 'terraform plan -out=tfplan'
                    }
                }
            }
        }
        stage('Terraform Apply') {
            when {
                expression { params.ACTION == 'apply' }
            }
            steps {
                dir('main') {
                    withAWS(credentials: 'access-key') {
                        sh 'terraform apply -auto-approve tfplan'
                    }
                }
            }
        }
        stage('Terraform Destroy') {
            when {
                expression { params.ACTION == 'destroy' }
            }
            steps {
                dir('main') {
                    withAWS(credentials: 'access-key') {
                        sh 'terraform destroy -auto-approve'
                    }
                }
                dir('state_management') {
                    withAWS(credentials: 'access-key') {
                        sh 'terraform init'
                        sh 'terraform destroy -auto-approve'
                    }
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
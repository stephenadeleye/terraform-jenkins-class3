pipeline {
    agent any
    parameters {
        choice(name: 'ACTION', choices: ['apply', 'destroy'], description: 'Select Terraform action to perform')
        string(name: 'TF_STATE_BUCKET', defaultValue: '', description: 'S3 bucket name for Terraform state (optional, auto-filled for destroy if available)')
        string(name: 'TF_LOCK_TABLE', defaultValue: '', description: 'DynamoDB table name for state locking (optional, auto-filled for destroy if available)')
    }
    environment {
        AWS_REGION = 'eu-west-2'
        TF_STATE_KEY = 'terraform/state/terraform.tfstate'
        STATE_OUTPUT_FILE = 'terraform_state_outputs.txt' // File to store bucket and table names
    }
    stages {
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    if (params.ACTION == 'destroy') {
                        // Unarchive the output file if it exists
                        try {
                            unarchive mapping: ["${env.STATE_OUTPUT_FILE}": "${env.STATE_OUTPUT_FILE}"]
                        } catch (Exception e) {
                            echo "No archived terraform_state_outputs.txt found, relying on parameters or manual input"
                        }
                    }
                }
            }
        }
        stage('Provision State Management Resources') {
            when {
                expression { params.ACTION == 'apply' }
            }
            steps {
                dir('state_management') {
                    withAWS(credentials: 'access-key') {
                        sh 'terraform init'
                        sh 'terraform apply -auto-approve'
                        // Capture outputs for bucket and table names
                        script {
                            env.TF_STATE_BUCKET = sh(script: 'terraform output -raw state_bucket_name', returnStdout: true).trim()
                            env.TF_LOCK_TABLE = sh(script: 'terraform output -raw lock_table_name', returnStdout: true).trim()
                            // Save outputs to a file
                            writeFile file: "${env.STATE_OUTPUT_FILE}", text: "TF_STATE_BUCKET=${env.TF_STATE_BUCKET}\nTF_LOCK_TABLE=${env.TF_LOCK_TABLE}"
                            // Archive the file for persistence
                            archiveArtifacts artifacts: "${env.STATE_OUTPUT_FILE}", fingerprint: true
                        }
                    }
                }
            }
        }
        stage('Terraform Init') {
            steps {
                dir('main') {
                    withAWS(credentials: 'access-key') {
                        script {
                            def bucket = params.TF_STATE_BUCKET
                            def table = params.TF_LOCK_TABLE
                            // For destroy, try to read from saved file if parameters are not provided
                            if (params.ACTION == 'destroy' && (!bucket || !table)) {
                                if (fileExists("${env.STATE_OUTPUT_FILE}")) {
                                    def outputs = readProperties file: "${env.STATE_OUTPUT_FILE}"
                                    bucket = outputs.TF_STATE_BUCKET ?: error('TF_STATE_BUCKET not found in output file')
                                    table = outputs.TF_LOCK_TABLE ?: error('TF_LOCK_TABLE not found in output file')
                                } else {
                                    error 'TF_STATE_BUCKET and TF_LOCK_TABLE must be provided for destroy action, or output file must exist'
                                }
                            } else if (params.ACTION == 'apply') {
                                bucket = env.TF_STATE_BUCKET ?: error('TF_STATE_BUCKET not set from apply action')
                                table = env.TF_LOCK_TABLE ?: error('TF_LOCK_TABLE not set from apply action')
                            }
                            sh "terraform init -backend-config=\"bucket=${bucket}\" -backend-config=\"key=${TF_STATE_KEY}\" -backend-config=\"region=${AWS_REGION}\" -backend-config=\"dynamodb_table=${table}\""
                        }
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
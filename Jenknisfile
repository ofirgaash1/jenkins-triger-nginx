pipeline {
    agent any

    environment {
        AWS_REGION = 'il-central-1'
    }

    parameters {
        string(name: 'ANSIBLE_PLAYBOOK', defaultValue: 'nginx.yml', description: 'Ansible playbook to run')
        string(name: 'NGINX_PORT', defaultValue: '6789', description: 'Port for Nginx')
        string(name: 'NGINX_STRING', defaultValue: '', description: 'String to configure in Nginx')
        string(name: 'ip_address', defaultValue: '', description: 'Public IP of the NGINX EC2')
        string(name: 'instance_id', defaultValue: '', description: 'Instance ID of the NGINX EC2')
    }

    stages {
        stage('Info') {
            steps {
                echo "Deploying to NGINX instance: ${params.instance_id} at IP: ${params.ip_address}"
            }
        }

        stage('Run Ansible Playbook') {
            steps {
                withCredentials([
                    string(credentialsId: 'YOUR_KEY', variable: 'YOUR_KEY'),
                    string(credentialsId: 'YOUR_SECRET', variable: 'YOUR_SECRET'),
                    file(credentialsId: 'KEY-PAIR', variable: 'KEYPAIR_PATH')
                ]) {
                    sh """
                        set -e

                        echo "Generating Ansible inventory..."
                        cat <<EOF > hosts
[nginx]
${params.ip_address}

[nginx:vars]
ansible_user=ubuntu
EOF

                        echo "======= HOSTS FILE ======="
                        cat hosts
                        echo "=========================="

                        echo "Disabling host key checking"
                        cat <<EOF > ansible.cfg
[defaults]
host_key_checking = False
EOF

                        echo "Configuring AWS CLI..."
                        aws configure set aws_access_key_id \$YOUR_KEY
                        aws configure set aws_secret_access_key \$YOUR_SECRET
                        aws configure set default.region $AWS_REGION

                        echo "Running Ansible Playbook..."
                        ansible-playbook -i hosts ${params.ANSIBLE_PLAYBOOK} \
                          -e "nginx_port=${params.NGINX_PORT} NGINX_STRING='${params.NGINX_STRING}'" \
                          --limit nginx \
                          --private-key \$KEYPAIR_PATH
                    """
                }
            }
        }
    }
}

pipeline {
    agent any

    parameters {
        string(name: 'ANSIBLE_PLAYBOOK', defaultValue: 'nginx.yml', description: 'Ansible playbook to run')
        string(name: 'NGINX_PORT', defaultValue: '6789', description: 'Port for Nginx')
        string(name: 'NGINX_STRING', defaultValue: 'sunday', description: 'String to configure in Nginx')
        string(name: 'ip_address', defaultValue: '51.17.85.10', description: 'Public IP of the NGINX EC2')
        string(name: 'instance_id', defaultValue: 'i-079644fc07481c698', description: 'Instance ID of the NGINX EC2')
    }

    stages {
        stage('Info') {
            steps {
                echo "Deploying to NGINX instance: ${params.instance_id} at IP: ${params.ip_address}"
                echo "Using playbook: ${params.ANSIBLE_PLAYBOOK}"
                echo "NGINX_PORT=${params.NGINX_PORT}, NGINX_STRING=${params.NGINX_STRING}"
            }
        }

        stage('Run Ansible Playbook') {
            steps {
                withCredentials([
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

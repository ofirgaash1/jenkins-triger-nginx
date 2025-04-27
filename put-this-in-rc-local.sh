#!/bin/bash

# ---------------------------
# LOG START
# ---------------------------

echo "===== Cloud-init DNS setup started =====" > /var/log/cloud-init-dns.log

# ---------------------------
# INSTALL AWS CLI v2
# ---------------------------

apt update -y
apt install -y unzip curl jq

echo "Installing AWS CLI v2..." | tee -a /var/log/cloud-init-dns.log

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install | tee -a /var/log/cloud-init-dns.log 2>&1

/usr/local/bin/aws --version | tee -a /var/log/cloud-init-dns.log 2>&1

rm -rf aws awscliv2.zip

# ---------------------------
# METADATA + DOMAIN CONFIG
# ---------------------------

TOKEN=$(curl -s -X PUT \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 3600" \
  http://169.254.169.254/latest/api/token)

IP_PUBLIC=$(curl -s \
  -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/public-ipv4)

echo "Instance public IP: $IP_PUBLIC" | tee -a /var/log/cloud-init-dns.log

DOMAIN_NAME="aws.cts.care."      # <-- make sure it ends with a dot
SUB_DOMAIN_PREFIX="ofir"
FULL_DOMAIN="${SUB_DOMAIN_PREFIX}.${DOMAIN_NAME}"

# ---------------------------
# FETCH HOSTED ZONE ID
# ---------------------------

ROUTE53_ZONE_ID=$(/usr/local/bin/aws route53 list-hosted-zones \
  --query "HostedZones[?Name == '$DOMAIN_NAME'].Id" \
  --output text)

echo "Fetched hosted zone ID: $ROUTE53_ZONE_ID" | tee -a /var/log/cloud-init-dns.log

# ---------------------------
# GET CURRENT RECORD IP
# ---------------------------

CURRENT_ROUTE53_IP=$(/usr/local/bin/aws route53 list-resource-record-sets \
  --hosted-zone-id "$ROUTE53_ZONE_ID" \
  --query "ResourceRecordSets[?Name == '$FULL_DOMAIN'].ResourceRecords[0].Value" \
  --output text)

echo "Current IP in DNS: $CURRENT_ROUTE53_IP" | tee -a /var/log/cloud-init-dns.log

# ---------------------------
# UPSERT DNS RECORD IF NEEDED
# ---------------------------

if [[ "$IP_PUBLIC" != "$CURRENT_ROUTE53_IP" && -n "$IP_PUBLIC" ]]; then
  echo "Updating DNS for $FULL_DOMAIN → $IP_PUBLIC" | tee -a /var/log/cloud-init-dns.log

  CHANGE_BATCH=$(cat <<EOF
{
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "${FULL_DOMAIN}",
        "Type": "A",
        "TTL": 300,
        "ResourceRecords": [
          {
            "Value": "${IP_PUBLIC}"
          }
        ]
      }
    }
  ]
}
EOF
)

  /usr/local/bin/aws route53 change-resource-record-sets \
    --hosted-zone-id "$ROUTE53_ZONE_ID" \
    --change-batch "$CHANGE_BATCH" | tee -a /var/log/cloud-init-dns.log 2>&1

else
  echo "No DNS update needed for $FULL_DOMAIN" | tee -a /var/log/cloud-init-dns.log
fi

echo "===== Cloud-init DNS setup finished =====" | tee -a /var/log/cloud-init-dns.log

# ---------------------------
# TRIGGER JENKINS WEBHOOK
# ---------------------------

echo "Triggering Jenkins build..." | tee -a /var/log/cloud-init-dns.log

JENKINS_USER="shapi"
JENKINS_API_TOKEN="112c74f9d488c71b9debd2e85568517a57"  # NOT the job token!

CRUMB=$(curl -s --user $JENKINS_USER:$JENKINS_API_TOKEN \
  "$JENKINS_URL/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,\":\",//crumb)")


INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/instance-id)

JENKINS_URL="http://vpn.aws.cts.care/job/ofir/buildWithParameters"
JENKINS_TOKEN="123123"

curl -X POST "$JENKINS_URL/buildWithParameters" \
  --user $JENKINS_USER:$JENKINS_API_TOKEN \
  -H "$CRUMB" \
  --data-urlencode "ip_address=$IP_PUBLIC" \
  --data-urlencode "instance_id=$INSTANCE_ID"


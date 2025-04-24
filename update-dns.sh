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

echo "Installing AWS CLI v2..." >> /var/log/cloud-init-dns.log

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install >> /var/log/cloud-init-dns.log 2>&1

/usr/local/bin/aws --version >> /var/log/cloud-init-dns.log 2>&1

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

echo "Instance public IP: $IP_PUBLIC" >> /var/log/cloud-init-dns.log

DOMAIN_NAME="aws.cts.care."      # <-- make sure it ends with a dot
SUB_DOMAIN_PREFIX="ofir"
FULL_DOMAIN="${SUB_DOMAIN_PREFIX}.${DOMAIN_NAME}"

# ---------------------------
# FETCH HOSTED ZONE ID
# ---------------------------

ROUTE53_ZONE_ID=$(/usr/local/bin/aws route53 list-hosted-zones \
  --query "HostedZones[?Name == '$DOMAIN_NAME'].Id" \
  --output text)

echo "Fetched hosted zone ID: $ROUTE53_ZONE_ID" >> /var/log/cloud-init-dns.log

# ---------------------------
# GET CURRENT RECORD IP
# ---------------------------

CURRENT_ROUTE53_IP=$(/usr/local/bin/aws route53 list-resource-record-sets \
  --hosted-zone-id "$ROUTE53_ZONE_ID" \
  --query "ResourceRecordSets[?Name == '$FULL_DOMAIN'].ResourceRecords[0].Value" \
  --output text)

echo "Current IP in DNS: $CURRENT_ROUTE53_IP" >> /var/log/cloud-init-dns.log

# ---------------------------
# UPSERT DNS RECORD IF NEEDED
# ---------------------------

if [[ "$IP_PUBLIC" != "$CURRENT_ROUTE53_IP" && -n "$IP_PUBLIC" ]]; then
  echo "Updating DNS for $FULL_DOMAIN → $IP_PUBLIC" >> /var/log/cloud-init-dns.log

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
    --change-batch "$CHANGE_BATCH" >> /var/log/cloud-init-dns.log 2>&1

else
  echo "No DNS update needed for $FULL_DOMAIN" >> /var/log/cloud-init-dns.log
fi

echo "===== Cloud-init DNS setup finished =====" >> /var/log/cloud-init-dns.log

# ---------------------------
# TRIGGER JENKINS WEBHOOK
# ---------------------------

echo "Triggering Jenkins build..." >> /var/log/cloud-init-dns.log

INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/instance-id)

JENKINS_URL="http://vpn.aws.cts.care/job/ofir/buildWithParameters"
JENKINS_TOKEN="123123"

curl -X POST "$JENKINS_URL?token=$JENKINS_TOKEN&ip_address=$IP_PUBLIC&instance_id=$INSTANCE_ID" \
  >> /var/log/cloud-init-dns.log 2>&1

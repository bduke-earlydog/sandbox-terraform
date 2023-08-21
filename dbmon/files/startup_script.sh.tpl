#!/bin/bash

#test

# Store Terraform template variables as Bash variables to keep code clean and easy to read.
declare -A DATABASE_MAP=( ${DATABASE_MAP_STRING} )
REGION="${REGION}"
PROJECT="${PROJECT}"
METADATA_KEY_PERFORM_DISK_FORMAT="${METADATA_KEY_PERFORM_DISK_FORMAT}"
PMM_ADMIN_PASSWORD="${PMM_ADMIN_PASSWORD}"
PMM_SQL_PASSWORD="${PMM_SQL_PASSWORD}"

# Setup the persistent disk that stores PMM data.
# Documentation: https://cloud.google.com/compute/docs/disks/format-mount-disk-linux
PMM_MOUNT_DIR="/mnt/pmm"
PERFORM_DISK_FORMAT=$(gcloud compute project-info describe --project=$PROJECT --format="get(commonInstanceMetadata.items.$METADATA_KEY_PERFORM_DISK_FORMAT)")
if [ "$PERFORM_DISK_FORMAT" = "true" ]; then
    echo "Formatting persistent disk."
    mkfs.ext4 -m 0 -E lazy_itable_init=0,lazy_journal_init=0,discard /dev/sdb
    gcloud compute project-info add-metadata --project=$PROJECT --metadata $METADATA_KEY_PERFORM_DISK_FORMAT=false
fi
if [ ! -d $PMM_MOUNT_DIR ]; then
    echo "Creating mount directory."
    mkdir $PMM_MOUNT_DIR
fi
if ! mountpoint -q $PMM_MOUNT_DIR; then
    echo "Mounting persistent disk."
    mount -t ext4 -o defaults /dev/sdb "$PMM_MOUNT_DIR"
    chmod a+w $PMM_MOUNT_DIR
fi

# Update and install necessary packages.
echo "Installing mysql-client."
apt-get update
apt-get install -y curl mysql-client

# Install cloud sql proxy and configure it as a service.
# Documentation: https://cloud.google.com/sql/docs/mysql/connect-auth-proxy
echo "Installing cloud sql proxy."
curl -o /usr/local/bin/cloud-sql-proxy https://storage.googleapis.com/cloud-sql-connectors/cloud-sql-proxy/v2.6.0/cloud-sql-proxy.linux.amd64
chmod +x /usr/local/bin/cloud-sql-proxy
CLOUD_SQL_PROXY_INSTANCES=""
for DB in "$${!DATABASE_MAP[@]}"; do
    PORT=$${DATABASE_MAP[$DB]}
    CLOUD_SQL_PROXY_INSTANCES+="\"$PROJECT:$REGION:$DB?port=$PORT\" "
done
cat <<ENDOFCONF >/etc/systemd/system/cloud-sql-proxy.service
[Install]
WantedBy=multi-user.target

[Unit]
Description=Cloud SQL Auth Proxy
Requires=network.target
After=network.target

[Service]
WorkingDirectory=/usr/local/bin
ExecStart=/usr/local/bin/cloud-sql-proxy $CLOUD_SQL_PROXY_INSTANCES
Restart=always
StandardOutput=journal
User=root
ENDOFCONF
systemctl daemon-reload
systemctl enable cloud-sql-proxy
systemctl start cloud-sql-proxy


# Install Docker.
# Documentation: https://docs.docker.com/engine/install/ubuntu/
echo "Installing Docker."
apt-get -y install ca-certificates curl gnupg
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin


# Install the PMM server as a docker container.
# Documentation: https://docs.percona.com/percona-monitoring-and-management/setting-up/server/docker.html
echo "Installing PMM server."
docker pull percona/pmm-server:2
docker run -v $PMM_MOUNT_DIR/srv:/srv -d --restart always --publish 80:80 --publish 443:443 --name pmm-server percona/pmm-server:2
docker exec -t pmm-server change-admin-password $PMM_ADMIN_PASSWORD

# Install the PMM client.
# Documentation: https://docs.percona.com/percona-monitoring-and-management/setting-up/client/index.html
echo "Installing PMM client."
wget https://repo.percona.com/apt/percona-release_latest.generic_all.deb
dpkg -i percona-release_latest.generic_all.deb
apt-get update
apt-get install -y pmm2-client

# Register the PMM client with the server.
# The node name is set manually, and the force flag is enabled, so that previous node configurations are overwritten. This keeps the node inventory clear and removes orphaned services.
echo "Registering PMM client."
NODE_IP=$(hostname -I | awk '{print $1}')
pmm-admin config --server-insecure-tls --server-url=https://admin:$PMM_ADMIN_PASSWORD@127.0.0.1:443 --force $NODE_IP generic pmm-client

# Add monitoring services.
# A service is added for each entry in the database_map array.
echo "Adding database services."
for DB in "$${!DATABASE_MAP[@]}"; do
    PORT=$${DATABASE_MAP[$DB]}
    pmm-admin add mysql --query-source=perfschema --username=pmm --password=$PMM_SQL_PASSWORD --service-name=$DB --host=127.0.0.1 --port=$PORT
done
# Purpose
This module is used to create a compute instance running Percona Monitoring and Management (PMM) software. Since it already has a Cloud SQL Proxy setup, it can also be used for performing manual MySQL queries requested by the customer.

# Usage
- PMM data is stored on a persistent disk seperate from the compute instance, so restarting or redeploying the instance will not cause any loss of monitoring data (other than the data that is not recorded while the instance is down).
- The instance has a static external IP address, which can be found in the `external_ip` output variable.
- In order to access the PMM webpage or SSH into the machine, IP ranges must be added to the appropriate allow lists (`allow_https` and `allow_ssh` respectively).
- Each entry in the `database_map` input will be added to both the Cloud SQL Proxy and PMM. The database name will be used as the name of the monitored service in PMM.
- The `pmm` MySql user password is randomly generated. If needed, it can be found in secrets manager under the `pmm_sql_password` secret.
- The `admin` PMM user password is randomly generated. If needed, it can be found in secrets manager under the `pmm_admin_password` secret.

# Important Notes
- Only a single instance can be running at any given time, since the persistent disk containing the PMM configuration and monitoring data can only be attached to one VM at any given time. This means redeploying the instance will involve short downtime as the instance is completely destroyed before being recreated.
- A project metadata key `perform_pmm_disk_format` is used to remember if a disk format has been performed already. After the first deployment of the module the disk will be properly formatted and the metadata value will be set to `false`. If for some reason you want to format the persistent data disk, set the value to `true` and restart or redeploy the instance.
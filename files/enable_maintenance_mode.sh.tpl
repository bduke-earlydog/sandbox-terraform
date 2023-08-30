#!/bin/bash
#
# ENABLE MAINTENANCE MODE
#
# This script should be run from a `sysops` server residing in the customer's project and it should be run
#  by the special sysops service account created for running these scripts.
#
# The `vars` file is sourced and expected to define the following variable:
#
#   * PROJECT_NAME
#   * LOG_FILE
#
# Please read the `README` before running this script

set -u

# Use the Terraform template variable to set the project name.
PROJECT_NAME=${PROJECT}

# Added `whoami` to prevent a permissions problem when writing to the log.
# When this script is used, it creates the log file owned by the current user.
# If another user used the script afterward, their writes to the log would fail.
LOG_FILE="/tmp/$(whoami)_maintenance_mode.log"

###############################################################
exit 1    # prevent accidental execution; remove before running
###############################################################

if ! test -f "$HOME/.ssh/google_compute_engine"; then
  echo "No compute engine SSH keys exist. Please generate them by connecting
  manually to any instance with the following command:

      gcloud compute ssh INSTANCE_NAME --zone=INSTANCE_ZONE

  Afterward, please re-run this script.";
  exit 1
fi


#  This helper function runs a shell command on all servers specified in an instance list.
#  It expects to be passed two variables:
#    1: an instance list; either "$webapp_and_api_instances" or "$worker_instances".
#    2: a shell command to run.
run_cmds_over_ssh() {
  while read -r instance_name instance_zone foo; do
    # All `gcloud compute ssh` commands below run as background processes.
    # This was an intentional design choice, so that the script executes as quickly as possible.
    gcloud compute ssh "$instance_name" --quiet --tunnel-through-iap --zone="$instance_zone" --command="$2" &>>"$LOG_FILE" \
      || echo "$(date +'%F:%T') ERROR (ssh) Couldn't connect to $instance_name in $instance_zone within $PROJECT_NAME." >>"$LOG_FILE" &
  done < <(echo "$1")
}

# This function allows us to trigger an error and exit with a message
# expects 1 variable
#     1: message
on_err () {
  echo $1 | tee "$LOG_FILE"
  exit 1
}

echo "Enabling maintenance mode for $PROJECT_NAME."
echo "(note: verbose output/error information will be logged to $LOG_FILE)"

# Set maintenance mode state for the project by setting project-wide metadata "maintenance_mode_enabled=true"
# If setting the metadata fails, exit without making any changes to the infrastructure
# Worker servers use this metadata to enable maintenance mode on themselves in the deploy_workers.sh script
gcloud compute project-info add-metadata --metadata=maintenance_mode_enabled=true &>>"$LOG_FILE" \
  || on_err "$(date +'%F:%T') ERROR (add-metadata) Failed to update maintenance_mode metadata, Enabling Maintenance Mode Failed, Exiting..."

# Get a list of all running instances in the project
instance_list=$(gcloud compute instances list --project="$PROJECT_NAME" | grep RUNNING)
# Use separate lists for the webapp/api servers and worker servers.
api_and_webapp_instances=$(echo "$instance_list" | grep -P "^(api|webapp)")

# For webapp/api servers: set a flag in the app's environment variables
CMD="
sudo sed -i 's/MAINTENANCE_MODE_ENABLED=\"false\"/MAINTENANCE_MODE_ENABLED=\"true\"/g' /opt/src/.env;
"
echo "Beginning SSH connections to webapp and api servers..."
run_cmds_over_ssh "$api_and_webapp_instances" "$CMD"

# Wait until all background jobs are finished.
wait $(jobs -p) && echo "Maintenance mode has been enabled for $PROJECT_NAME."

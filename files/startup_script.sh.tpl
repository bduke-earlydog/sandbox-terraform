#!/bin/bash

declare -A DATABASE_MAP=( ${DATABASE_MAP_STRING} )

cat << 'EOF' > /tmp/enable_maintenance_mode.sh
${ENABLE_MAINTENANCE_MODE_SCRIPT}
EOF

cat << 'EOF' > /tmp/disable_maintenance_mode.sh
${DISABLE_MAINTENANCE_MODE_SCRIPT}
EOF
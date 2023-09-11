#!/bin/bash

# Example of how to create a file and place it on the instance.
# `some_script_i_want.sh.tpl` is evaluated by Terraform and supplied input variables are injected. The result is stored in the `local.some_script` variable.
# The contents of `local.some_script` variable is then injected into the startup script template (this file) and stored in the `local.startup_script` variable.
# The `local.startup_script` variable can then be passed to the instance template as metadata, which will run whenever the instance starts.
# It's important to note the single quotes around the heredoc delimiter: without them the script will not be properly escaped and variables/commands wiil be expanded/evaluated/run.
cat << 'EOF' > /tmp/some_script_i_want.sh
${SOME_SCRIPT}
EOF
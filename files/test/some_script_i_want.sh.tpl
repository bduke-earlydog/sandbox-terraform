#!/bin/bash

# This is an example showing usage of a Terraform template to create a bash script.

# Assign the template substitution to a bash variable.
# This isn't necessary, but makes writing the rest of the script cleaner since you don't switch between template variables and bash variables frequently.
PROJECT=${PROJECT_ID}

echo "$PROJECT is the best!"
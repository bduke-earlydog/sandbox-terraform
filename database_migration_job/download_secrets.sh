#!/bin/bash
# Downloads all secrets that start with 'env_' and their values, and stores them in a .env file.
echo 'Downloading secrets...'
projectId=$(gcloud config get-value project)
mapfile -t secrets < <(gcloud --project=${projectId} secrets list --format="value(name)")
secrets=("${secrets[@]:1}")
for secret in "${secrets[@]}"; do
    if [[ $secret == env_* ]]; then
        value=$(gcloud secrets versions access latest --project="$projectId" --secret="$secret" 2>&1)
        if [ $? -eq 0 ]; then
            echo "${secret}=${value}" >> .env
        else
            echo "${secret}=" >> .env
        fi
    fi
done
echo 'Secrets downloaded.'
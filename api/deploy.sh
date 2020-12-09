#! /bin/sh
stage=$1

echo "Stage: $stage"

aws s3 cp ./ s3://trashcansensor-"$stage"-storage/api/code --recursive --exclude "__pycache__/**" --exclude ".DS_Store" --exclude "deploy.sh"
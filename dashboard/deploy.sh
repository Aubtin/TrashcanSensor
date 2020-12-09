#! /bin/sh
stage=$1

echo "Stage: $stage"

aws s3 cp ./dist/bundle.js s3://trashcansensor-"$stage"-storage/dashboard/bundle.js
aws s3 cp ./public/index.html s3://trashcansensor-"$stage"-storage/dashboard/index.html
aws s3 cp ./public/manifest.json s3://trashcansensor-"$stage"-storage/dashboard/manifest.json

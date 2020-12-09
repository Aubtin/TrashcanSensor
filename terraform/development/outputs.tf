output "TrashcanBucketName" {
  value = aws_s3_bucket.TrashcanS3Bucket.bucket
}

output "apiIP" {
  value = aws_eip.ip.public_ip
}
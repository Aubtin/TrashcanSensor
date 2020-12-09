output "TrashcanBucketName" {
  value = aws_s3_bucket.TrashcanS3Bucket.bucket
}

output "apiIP" {
  value = aws_eip.ip.public_ip
}

output "cloudfrontDomain" {
  value = aws_cloudfront_distribution.s3_distribution.domain_name
}
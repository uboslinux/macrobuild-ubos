aws configure
AWS Access Key ID [None]: xxx
AWS Secret Access Key [None]: xxx
Default region name [None]: us-east-1
Default output format [None]: json
[root@ip-172-30-0-40 ami]# aws s3 cp image2.img s3://cldstr-users-testing/image2.img
upload: ./image2.img to s3://cldstr-users-testing/image2.img


cat ~/.aws/config
[default]
output = json
region = us-east-1

cat ~/.aws/credentials 
[default]
aws_access_key_id = xxx
aws_secret_access_key =  xxx


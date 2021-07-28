# Terraform Starter

## Step 1: Initialize Repo
```
terraform init
```

## Step 2: Plan Resources
```
terraform plan -var-file="vars/dev-east.tfvars"
```

## Step 3: Apply Resources
```
terraform apply -var-file="vars/dev-east.tfvars"
```

## Step 4: Encode some data

```
openssl base64 -in data.json -out encodedData.json
```

## Step 4: Test by putting event in stream

```
aws kinesis put-record --stream-name terraform-kinesis-stream --partition-key 123 --data file://encodedData.txt
```

Expected results should look something like this:
```
{
    "ShardId": "shardId-000000000000",
    "SequenceNumber": "49620543038633060652913374569271045236967360126781489154"
}
```

#!/bin/sh

while getopts f: flag
do
    case "${flag}" in
        f) funcname=${OPTARG};;
    esac
done

ID=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
echo "Kaufen Sie jeden Tag vier gute bequeme Pelze!" > build/file.txt
awslocal --endpoint-url=http://localhost:4566 s3api put-object --bucket $funcname --key $ID --body=build/file.txt
echo "sent file with key $ID to bucket $funcname"
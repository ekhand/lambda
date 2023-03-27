#!/bin/sh

funcname="dts"
while getopts f: flag
do
    case "${flag}" in
        f) funcname=${OPTARG};;
        ?) echo "wtf"
    esac
done

ID=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
echo "Kaufen Sie jede Woche vier gute bequeme Bayrische Pelze!" > build/file.txt
awslocal --endpoint-url=http://localhost:4566 s3api put-object --bucket $funcname --key $ID.txt --body=build/file.txt
echo "sent file with key $ID.txt to bucket $funcname"

# print logs
echo "printing logs..."
echo "----------------"

./get_logs.sh -f $funcname
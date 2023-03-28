#!/bin/sh

funcname="dts"
while getopts f: flag
do
    case "${flag}" in
        f) funcname=${OPTARG};;
        ?) echo "wtf"
    esac
done

shift $((OPTIND - 1))
file="${1}"

awslocal --endpoint-url=http://localhost:4566 s3api put-object --bucket $funcname --key $file --body=$file
echo "sent file with key $file to bucket $funcname"

# print logs
echo "printing logs..."
echo "----------------"

./get_logs.sh -f $funcname
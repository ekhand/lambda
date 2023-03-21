#!/bin/sh

new=false
funcname="dts"
dir=$(pwd)
while getopts 'nhf:' OPTION
do
  case "$OPTION" in
    n)
        new=true
        ;;
    f)
        funcname=${OPTARG}
        ;;
    h)
        echo "use [-n] to clear and start a new s3 bucket"
        exit 1
        ;;
  esac
done
shift "$(($OPTIND -1))"

# check that localstack is online
if ! [[ $(docker ps -a | grep "localstack_main" | wc -l) > 0 ]]; then
    echo "localstack is not running. exiting..."
    exit 1
fi

if ! [ -d "$dir/build" ]; then
    mkdir build
else 
    rm build/function.zip
fi

# build and zip go
GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -o ./build/main ./func/main.go
cd ./build
zip -T function.zip main
cd ../
echo "lambda function built."

# check for running lambda
running=$(awslocal lambda list-functions | grep FunctionName)
if [[ "$running" == *"\"$funcname\""* ]]; then
    echo "running $funcname lambda found. deleting..."
    awslocal lambda delete-function --function-name="$funcname"
fi

# clear existing lambda logs
awslocal --endpoint-url=http://localhost:4566 logs delete-log-group --log-group-name="/aws/lambda/$funcname"

# launch updated lambda
echo "launching updated $funcname lambda..."
awslocal --endpoint-url=http://localhost:4566 \
lambda create-function --function-name $funcname \
--zip-file fileb://$dir/build/function.zip \
--handler main --runtime go1.x \
--role arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

# launch/skip s3 bucket
running=$(awslocal s3 ls)
creates3=true
if [[ "$running" == *"$funcname"* ]]; then
    if $new ; then
        echo "s3 bucket exists. deleting..."
        awslocal s3 rb s3://$funcname --force
    else
        echo "s3 bucket exists. skipping s3 creation..."
        creates3=false
    fi
fi

# create new bucket if needed
if $creates3; then
    echo "creating s3 bucket..."
    awslocal --endpoint-url=http://localhost:4566 s3 mb s3://$funcname
fi

# set bucket configuration
echo "configuring s3 notifications..."
sed "s/<FUNCTIONNAME>/$funcname/g" s3_notif_template.json > build/s3_notif_config.json # create notif link
awslocal --endpoint-url=http://localhost:4566 \
s3api put-bucket-notification-configuration --bucket $funcname \
--notification-configuration file://build/s3_notif_config.json

# print startup logs
if [ -d $funcname.log ]; then
    rm $funcname.log 
fi
echo "setup complete. outputting log:"

echo "-------------------------------" # startup logs
awslocal lambda invoke --function-name $funcname $funcname.log --log-type Tail \
--query 'LogResult' --output text |  base64 -d
echo # new line

echo "-------------------------------" # any possible errors
out=$(cat $funcname.log | jq)
if [[ "$out" == "null" ]]; then
    rm $funcname.log # unnecessary, delete
    echo "No startup errors detected."
else
    echo $out # print
fi

echo "-------------------------------" # full log trace
./get_logs.sh -f $funcname
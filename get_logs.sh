#!/bin/bash

while getopts f: flag
do
    case "${flag}" in
        f) funcname=${OPTARG};;
    esac
done

awslocal --endpoint-url=http://localhost:4566 logs tail "/aws/lambda/${funcname}"
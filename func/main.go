// main.go
package main

import (
	"context"
	"fmt"
	"log"
	"os"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/credentials"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/s3"
	"github.com/aws/aws-sdk-go/service/s3/s3manager"
)

var (
	downloader *s3manager.Downloader
)

// main function for startup
func main() {
	// create s3 session
	err := setupS3()
	if err != nil {
		log.Printf("COULD NOT START LAMBDA FUNC: %v", err)
		os.Exit(1)
	}

	// Make the handler available for Remote Procedure Call by AWS Lambda
	lambda.Start(handler)
}

// lambda event handler
func handler(ctx context.Context, s3Event events.S3Event) {
	for _, record := range s3Event.Records {
		item := record.S3
		log.Printf("[%s - %s] Bucket: %s, Key: %s \n", record.EventSource, record.EventTime, item.Bucket.Name, item.Object.Key)

		buf := aws.NewWriteAtBuffer([]byte{})
		_, err := downloader.Download(buf, &s3.GetObjectInput{
			Bucket: aws.String(item.Bucket.Name),
			Key:    aws.String(item.Object.Key),
		})
		if err != nil {
			log.Printf("[ERROR] unable to download %s from %s: %v", item.Object.Key, item.Bucket.Name, err)
		} else {
			log.Printf("Downloaded %v bytes from %s", len(buf.Bytes()), item.Object.Key)
			log.Printf("Body: \n\t%v", string(buf.Bytes()))
		}
	}
}

// HELPER FUNCS

// connects to AWS and creates an S3 downloader
// config params are temporary for localstack testing and development purposes
func setupS3() error {
	sess, err := session.NewSessionWithOptions(
		session.Options{
			Config: aws.Config{
				Credentials:      credentials.NewStaticCredentials("localstack", "localstack-secret", ""),     // no token
				Region:           aws.String("us-east-1"),                                                     // TEMPORARY
				Endpoint:         aws.String(fmt.Sprintf("http://%s:4566", os.Getenv("LOCALSTACK_HOSTNAME"))), // TEMPORARY (localstack s3 endpt)
				S3ForcePathStyle: aws.Bool(true),
			},
		},
	)
	if err != nil {
		return fmt.Errorf("failed to connect to s3: %w", err)
	}

	// create downloader for events (GLOBAL)
	downloader = s3manager.NewDownloader(sess)
	return nil
}

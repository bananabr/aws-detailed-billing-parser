#!/bin/bash

function usage
{
    echo "usage: job [[-pm] | [-h]]"
    echo "Parameters:"
    echo "-b  | --bucket = S3 bucket name where AWS usage reports are stored"
    echo "-r  | --report = aws usage report name"
    echo "-a  | --account = account id number"
    echo "-e  | --es-host = Elastic Search hostname or ip address"
    echo "-p  | --es-port = Elastic Search port"
    echo "-pm | --previous-month = process the previous month from current date"
}

REPORT_NAME='HourlyCostAndUsageReport'
YEAR=$(date +%Y)
MONTH=$(date +%m)
NEXT_YEAR=$(date --date='+1 month' +%Y)
NEXT_MONTH=$(date --date='+1 month' +%m)
LOCAL_FOLDER='/tmp'

ES_HOST='localhost'
ES_PORT=9200

# Process input parameters
while [ "$1" != "" ]; do
    case $1 in
        -b | --bucket )         shift
				BUCKET=$1
                                ;;
        -r | --report )         shift
				REPORT_NAME=$1
                                ;;
        -a | --account )        shift
				ACCOUNT=$1
                                ;;
        -e | --es-host )        shift
				ES_HOST=$1
                                ;;
        -p | --es-port )        shift
				ES_PORT=$1
                                ;;
        -pm | --previous-month ) echo "Processing previous month!"
                                MONTH=$(date --date='-1 month' +%m)
                                YEAR=$(date --date='-1 month' +%Y)
                                NEXT_YEAR=$(date +%Y)
                                NEXT_MONTH=$(date +%m)
                                ;;
        -h | --help )           usage
                                exit
                                ;;
    esac
    shift
done

#Change to local working folder
cd $LOCAL_FOLDER


for i in $(seq -f "%05g" 1 100)
do
	DBR_FILE="${REPORT_NAME}-$i.csv"
	GZIP_FILE=$DBR_FILE.gz
	
	# Copy the file from bucket to local folder
	aws s3 cp "s3://$BUCKET/${PATH_PREFIX}${REPORT_NAME}/${YEAR}${MONTH}01-${NEXT_YEAR}${NEXT_MONTH}01/$GZIP_FILE" . || break

	# Extract the gziped file
	gunzip  $GZIP_FILE
done

DBR_FILE="${REPORT_NAME}-00001.csv"
for i in $(seq -f "%05g" 2 100)
do
	CONCAT_FILE="${REPORT_NAME}-$i.csv"
	tail -n +2 $CONCAT_FILE >> $DBR_FILE || break
done

# Process the file with dbrparser
dbrparser -i $DBR_FILE -e $ES_HOST -p $ES_PORT -t 2 -bm 2 -y $YEAR -m $MONTH --delete-index

# Remove processed file
rm -f "${REPORT_NAME}-*.csv"

echo 'Finished processing...'

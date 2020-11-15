#!/usr/bin/env bash
set -eu -o pipefail

source ./sensitive-data.sh

export DOCKER_IMAGE=${DOCKER_IMAGE:-altinity/dbench:latest}
export DBENCH_NAMESPACE=${DBENCH_NAMESPACE:-default}
export DOCKER_PUBLISH=${DOCKER_PUBLISH:-no}

if [[ "yes" == ${DOCKER_PUBLISH} ]]; then
  bash ./docker-publish.sh
fi

ALL_STORAGE_CLASSES_FILE=${ALL_STORAGE_CLASSES_FILE:-./aws-ebs-storage-classes.yaml}
CSV_FILE=${CSV_FILE:-./raw_data/benchmarks.csv}
echo '"EBS type","EBS Size GiB","File Size GiB","Read only IOPS","Write only IOPS","Read only BW MiB/s","Write only BW MiB/s","avg Read Latency","avg Write Latency","sequental Read BW MiB/s","sequental Write BW MiB/s","mixed random read IOPS","mixed random write IOPS"' > $CSV_FILE
kubectl apply -f $ALL_STORAGE_CLASSES_FILE

# todo think about kubectl get storageclass -o name
# todo think about parrallel job running
ALL_STORAGE_CLASSES=$(grep "name:" $ALL_STORAGE_CLASSES_FILE | cut -d ":" -f 2)
for STORAGE_CLASS in $ALL_STORAGE_CLASSES; do
  export STORAGE_CLASS=$STORAGE_CLASS
  for ST_SIZE in 100 500 1000; do
    for FIO_PERCENT in 50 75 80; do
      F_SIZE=$( echo "scale=0;${ST_SIZE}*${FIO_PERCENT}/100" | bc -l)
      export FIO_SIZE="${F_SIZE}G"
      export STORAGE_SIZE="${ST_SIZE}Gi"
      export LOG_FILE=./raw_data/$STORAGE_CLASS-$STORAGE_SIZE-$FIO_SIZE.log
      if [[ ! -f $LOG_FILE ]]; then
        cat ./dbench.yaml | envsubst | kubectl apply -n $DBENCH_NAMESPACE -f -

        while [[ "0" == $(kubectl logs -n ${DBENCH_NAMESPACE} jobs/dbench-${STORAGE_CLASS} | grep -c "Dbench Summary END") ]]; do
          echo "jobs/dbench-${STORAGE_CLASS} not ready sleep 5 seconds"
          sleep 5
        done

        kubectl logs -n ${DBENCH_NAMESPACE} jobs/dbench-${STORAGE_CLASS} > $LOG_FILE

        cat ./dbench.yaml | envsubst | kubectl delete -n $DBENCH_NAMESPACE -f -

        echo "=== STORAGE_CLASS=$STORAGE_CLASS STORAGE_SIZE=$STORAGE_SIZE DONE ==="
      else
        echo "=== STORAGE_CLASS=$STORAGE_CLASS STORAGE_SIZE=$STORAGE_SIZE ALREADY EXISTS ==="
      fi
      RANDOM_READ_IOPS=$(tail -n 5 $LOG_FILE | head -n 1 | cut -d " " -f 4 | cut -d "/" -f 1)
      RANDOM_WRITE_IOPS=$(tail -n 5 $LOG_FILE | head -n 1 | cut -d " " -f 4 | cut -d "/" -f 2)
      RANDOM_READ_BW=$(tail -n 5 $LOG_FILE | head -n 1 | cut -d " " -f 6 | cut -d "/" -f 1 | cut -d "M" -f 1)
      RANDOM_WRITE_BW=$(tail -n 5 $LOG_FILE | head -n 1 | cut -d " " -f 8 | cut -d "/" -f 1 | cut -d "M" -f 1)
      AVG_LATENCY_READ=$(tail -n 4 $LOG_FILE | head -n 1 | cut -d " " -f 5 | cut -d "/" -f 1)
      AVG_LATENCY_WRITE=$(tail -n 4 $LOG_FILE | head -n 1 | cut -d " " -f 5 | cut -d "/" -f 2)
      SEQ_READ_BW=$(tail -n 3 $LOG_FILE | head -n 1 | cut -d " " -f 3 | cut -d "/" -f 1 | cut -d "M" -f 1)
      SEQ_WRITE_BW=$(tail -n 3 $LOG_FILE | head -n 1 | cut -d " " -f 5 | cut -d "/" -f 1 | cut -d "M" -f 1)
      MIXED_RANDOM_READ_IOPS=$(tail -n 2 $LOG_FILE | head -n 1 | cut -d " " -f 5 | cut -d "/" -f 1)
      MIXED_RANDOM_WRITE_IOPS=$(tail -n 2 $LOG_FILE | head -n 1 | cut -d " " -f 5 | cut -d "/" -f 2)
      echo "$STORAGE_CLASS,$ST_SIZE,$F_SIZE,$RANDOM_READ_IOPS,$RANDOM_WRITE_IOPS,$RANDOM_READ_BW,$RANDOM_WRITE_BW,$AVG_LATENCY_READ,$AVG_LATENCY_WRITE,$SEQ_READ_BW,$SEQ_WRITE_BW,$MIXED_RANDOM_READ_IOPS,$MIXED_RANDOM_WRITE_IOPS" >> $CSV_FILE
    done
  done
done

# please install https://github.com/chmln/sd
sd '\.,' ',' $CSV_FILE
sd '(\d+)\.(\d+)k' '$1$2 00' $CSV_FILE
sd '(\d+) (00)' '$1$2' $CSV_FILE
# sd '(\d{1})(\d{3})KiB' '$1.$2' $CSV_FILE

grep 'KiB' $CSV_FILE | while read line
do
  echo "$line" | grep -E "[[:digit:]]+KiB" -o | while read FROM_KiB
  do
    TO_MiB=$(echo $FROM_KiB | numfmt --from=iec-i --suffix=B --format="%.3f" --to-unit=Mi | sd 'B' '')
    sd $FROM_KiB $TO_MiB $CSV_FILE
  done
done
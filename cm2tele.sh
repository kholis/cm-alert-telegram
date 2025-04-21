#!/usr/bin/env bash
BASE_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Please edit this
BOT_TOKEN="XXXXXXXX"
CHAT_ID="1234567890"
TOPIC_ID=""           # Optional. For supergroup with topic only.
CM_PORT=7180          # CM NonSecure: 7180, CM Secure: 7183
#export https_proxy=http://proxy.corporate.com:8080

# Define var
col1="${BASE_DIR}/col1.txt"
col2="${BASE_DIR}/col2.txt"
alert_tele="${BASE_DIR}/alert-tele.txt"

# Get alert filename
cp $1 ${BASE_DIR}/
filename=`basename $1`
alert_file="${BASE_DIR}/${filename}"

# Alert length
#alert_length=`cat ${alert_file} | jq length`

# Parse alert
cat ${alert_file} | jq '.[].body.alert
| .source as $URL 
| .content as $DTL 
| select(.content | contains("The following health tests are bad: host health.") | not)
| select(.content | contains("Percent healthy or concerning:") | not)
| select(.content | contains("Health test changes:") | not)
| select(.content | contains("Canary test failed") | not)
| select(.content | contains("NIFI_NODE_CONNECTIVITY") | not)
| select(.content | contains("SWAP_MEMORY_USAGE") | not)
| .attributes 
| select (.CURRENT_HEALTH_SUMMARY | contains(["RED"])) 
| .ALERT_SUMMARY, $DTL, .SERVICE_DISPLAY_NAME, .CLUSTER_DISPLAY_NAME, $URL' | grep -o '"[^"]\+"' | sed -e "s/${CM_PORT}.*/${CM_PORT}\"\n/g" > ${col2}

# Get number of alert
alert_length=`grep ${CM_PORT} ${col2} | wc -l`

# Generate col1
rm -f $col1
for i in `seq 1 ${alert_length}`; do
	echo "*SUMMARY:*
*DETAIL:*
*SERVICE:*
*CLUSTER:*
*CM_URL:*
 " >> ${col1}
done

# Cleaning unnecessary word
sed -i 's/The health test result for //g' $col2
sed -i "s/The health of this role's host is bad. //g" $col2
sed -i 's/The following health tests are bad: //g' $col2
sed -i 's/This health test //g' $col2
sed -i 's/The health of service //g' $col2
sed -i 's/The health of role //g' $col2
sed -i 's/has become bad/is bad/g' $col2
sed -i 's/Become Bad/is bad/g' $col2
sed -i 's/Percent healthy or concerning:/Concerning:/g' $col2
sed -i 's/Percent healthy:/Health:/g' $col2
sed -i 's/Critical threshold:/Threshold:/g' $col2
sed -i 's/_HOST_HEALTH//g' $col2
sed -i 's/_HEALTHY//g' $col2
sed -i 's/_HEALTH//g' $col2
sed -i 's/_SERVER//g' $col2
sed -i 's/This role is //g' $col2
sed -i "s/This role's //g" $col2
sed -i "s/This role //g" $col2
sed -i "s/The 99th percentile/Percentile/g" $col2
sed -i "s/over the previous/over prev/g" $col2
sed -i "s/second(s)/s/g" $col2
sed -i "s/The Cloudera Manager Agent/cm-agent/g" $col2
sed -i "s/NIFIREGISTRY_NIFI_REGISTRY/NIFI_REGISTRY/g" $col2
sed -i "s/STREAMS_MESSAGING_MANAGER_STREAMS_MESSAGING_MANAGER/SMM/g" $col2
sed -i "s/streams_messaging_manager/smm/g" $col2
sed -i "s/SCHEMAREGISTRY_SCHEMA_REGISTRY/SCHEMA_REGISTRY/g" $col2
sed -i "s/HDFS_FAILOVERCONTROLLER/HDFS_ZKFC/g" $col2
sed -i "s/JOURNAL_NODE_FSYNC/JN_FSYNC/g" $col2
sed -i "s/RANGER_RANGER/RANGER/g" $col2
sed -i "s/NIFI_NIFI/NIFI/g" $col2
sed -i "s/KNOX_KNOX/KNOX/g" $col2
sed -i "s/KAFKA_KAFKA/KAFKA/g" $col2
sed -i "s/FLINK_FLINK_HISTORY/FLINK_HS/g" $col2
sed -i "s/QUEUEMANAGER_QUEUEMANAGER_/QM_/g" $col2
sed -i "s/EVENT is bad/EVENT_SERVER is bad/g" $col2
sed -i 's/reflects the health of the active ResourceManager.//g' $col2
sed -i 's/ResourceManager summary://g' $col2
sed -i 's/(Availability: /(/g' $col2
sed -i 's/, Health:/,/g' $col2

# Telegram Markdown escape char on col2
sed -i 's/_/\\_/g' ${col2}
sed -i 's/*/\\*/g' ${col2}
sed -i 's/`/\\`/g' ${col2}

# Join column
paste -d " " $col1 $col2 > ${alert_tele}

# Send to Telegram group
if [ -s ${alert_tele} ]; then
  sed -i '1s/^/\n/' ${alert_tele}
  sed -i '1s/^/🧨 *CM Alerts:*\n/' ${alert_tele}
  if [ "${TOPIC_ID}" == "" ]; then
    curl -X POST https://api.telegram.org/bot${BOT_TOKEN}/sendMessage \
         -d "chat_id=-${CHAT_ID}" \
         -d "parse_mode=MARKDOWN" \
         --data-urlencode "text=$(cat ${alert_tele})"
  else
    curl -X POST https://api.telegram.org/bot${BOT_TOKEN}/sendMessage \
         -d "chat_id=-${CHAT_ID}" \
         -d "message_thread_id=${TOPIC_ID}" \
         -d "parse_mode=MARKDOWN" \
         --data-urlencode "text=$(cat ${alert_tele})"
  fi
fi

#!/usr/bin/env bash
BASE_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Please edit this
BOT_TOKEN="XXXXXXXX"
CHAT_ID="1234567890"
CM_PORT=7180 # Secure: 7183, NonSecure: 7180
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
cat ${alert_file} | jq '.[].body.alert| .source as $URL | .content as $DTL | .attributes | select (.CURRENT_HEALTH_SUMMARY | contains(["RED"])) | .ALERT_SUMMARY, $DTL, .SERVICE_DISPLAY_NAME, .CLUSTER_DISPLAY_NAME, $URL' | sed -e 's/\[//g' | sed -e 's/\]//g' | sed '/^[[:space:]]*$/d' | sed -e 's/^[[:space:]]*//' | sed -e "s/${CM_PORT}.*/${CM_PORT}\"\n/g" > ${col2}

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
sed -i 's/The health of //g' $col2
sed -i 's/has become bad/is bad/g' $col2

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
  curl -X POST https://api.telegram.org/bot${BOT_TOKEN}/sendMessage \
       -d "chat_id=-${CHAT_ID}" \
       -d "parse_mode=MARKDOWN" \
       --data-urlencode "text=$(cat ${alert_tele})"
fi

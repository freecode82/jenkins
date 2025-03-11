#!/bin/bash

JENKINS_URL="http://localhost:8080"
USER_ID="admin"
TOKEN="your token"
OPERATION=$1
NODE_NAME=$2
START_NUMBER=$3
END_NUMBER=$4
WORK_DIR=$5 #WHEN RENAME, NEW NODENAME
NEW_START_NUMBER=$6
NEW_END_NUMBER=$7

RESULT_FILE=result_key.log
EXECUTORS=1

COOKIEJAR="/tmp/cookies"
COM_VERSION=21762

#===ssh agent setting======
SSH_HOST="127.0.0.1"
CRED_ID="your info"
SSH_PORT=22
#===ssh agent setting end===

usage() {
  echo "$(basename $0) operation node_name start_number end_number work_dir"
  echo "create ex) $(basename $0) create testnode 0 3 /tmp"
  echo "delete ex) $(basename $0) delete testnode 0 3"
  echo "rename ex) $(basename $0) rename testnode 0 3 rename-testnode"
  echo "rename ex) $(basename $0) rename testnode 0 3 rename-testnode 0 3"
  echo "rename ex) $(basename $0) rename testnode 0 3 rename-testnode 5 8"
  echo "explain: Rename 10 nodes from aaa-0 to aaa-9 to bbb $(basename $0) rename aaa 0 9 bbb"
  echo "when replacing bbb-1 width ccc-1 $(basename $0) rename bbb 1 1 ccc"
  exit 1
}



echo "operation $OPERATION"

if [[ $OPERATION != "create" ]] && [[ $OPERATION != "delete" ]] && [[ $OPERATION != "rename"]]; then
  echo "operation value only [create] or [delete] or [rename]"
  usage
fi

if [[ "$OPERATION" == "delete" ]]; then
  if [ $# -ne 4 ]; then
    echo "error: argument count invalid"
    usage
  fi
elif [[ "$OPERATION" == "create" ]]; then
  if [ $# -ne 5 ]; then
    echo "error: argument count invalid"
    usage
  fi
else #rename
  if [ $# -ne 5] && [ $# -ne 7 ]; then
    echo "error: argument count invalid"
    usage
  fi
fi

re='^[0-9]+$'
if ![[$START_NUMBER =~ $re]] || ![[$END_NUMBER =~ $re]]; then
  echo "error: number argument Not a number"
  usage
fi

if [[$OPERATION == "rename"]] && [[$# -eq 7]]; then
  if ![[$NEW_START_NUMBER =~ $re]] || ![[$NEW_END_NUMBER =~ $re]]; then
    echo "error: number argument Not a number"
    usage
  fi
fi

#cookie directory check
if [ ! -d $COOKIEJAR ]; then
  mkdir -p $COOKIEJAR
fi

#jenkins version check
result=$(curl -s -u ${USER_ID}:${TOKEN} ${JENKINS_URL}/api/)
output="${result#*data-version=}"
VERSION=$(echo $output | awk -F'>' '{ gsub("\"","", $1); print $1}')
CUR_VERSION=${VERSION//./}

get_crumb()
{
  if [ $CUR_VERSION -lt $COM_VERSION ]; then
    CRUMB=$(curl -fail -0 -u "${USER_ID}:${TOKEN}" ''${JENKINS_URL}/'crumbIssuer/api/xml?xpath=concat(//crumbRequestField,":",//crumb)' 2>/dev/null || echo "N/A")
    echo "beforme"
  else
   #after 2.176.2 session is required
    CRUMB=$(curl -fail -0 --cookie-jar ${COOKIEJAR} -u "${USER_ID}:${TOKEN}" ''${JENKINS_URL}/'crumbIssuer/api/xml?xpath=concat(//crumbRequestField,":",//crumb)' 2>/dev/null || echo "N/A")
    echo "after"
  fi
}


show_enable_crumb()
{
  if [[ ${CRUMB} != "N/A" ]]; then
    echo "CSRF Enabled"
  else
    echo "CSRF not enabled"
  fi
}


#echo ${CRUMB}

node_create()
{
  get_crumb
  show_enable_crumb

  echo $(date) | tee -a $RESULT_FILE
  while [ ${START_NUMBER} -le ${END_NUMBER} ]
  do
    NEW_NODE_NAME=${NODE_NAME}-${START_NUMBER}
    DESC=${NEW_NODE_NAME}
    LABELS=${NODE_NAME}

    #MAKE SSH AGENT -----------------
    #jenkins version 2.204.3 node make json value sample
    #{"name": "test111", "nodeDescription": "test111", "numExecutors": "1", "remoteFS": "/tmp", "labelString": "test111", "mode": "NORMAL", "": ["hudson.plugins.sshslaves.SSHLauncher", "hudson.slaves.RetentionStrategy$Always"], "launcher": {"stapler-class": "hudson.plugins.sshslaves.SSHLauncher", "$class": "hudson.plugins.sshslaves.SSHLauncher", "host": "127.0.0.1", "credentialsId": "d9axxxxxxxf5", "": "0", "sshHostKeyVerificationStrategy": {"stapler-class": "hudson.plugins.sshslaves.verifiers.KnownHostsFileKeyVerificationStrategy", "$class": "hudson.plugins.sshslaves.verifiers.KnownHostsFileKeyVerificationStrategy"}, "port": "22", "javaPath": "", "jvmOptions": "", "prefixStartSlaveCmd": "", "suffixStartSlaveCmd": "", "launchTimeoutSeconds": "", "maxNumRetries": "", "retryWaitTime": "", "tcpNoDelay": true, "workDir": ""}, "retentionStrategy": {"stapler-class": "hudson.slaves.RetentionStrategy$Always", "$class": "hudson.slaves.RetentionStrategy$Always"}, "nodeProperties": {"stapler-class-bag": "true"}, "type": "hudson.slaves.DumbSlave", "Jenkins-Crumb": "2b579e12e859c793xxxxxx8"}

    #below api not running in jenkins version 2.204.3, another version try
    #RESPONSE=$(curl -L -s -o /dev/null -w "%{http_code}" -u "${USER_ID}:${TOKEN}" -H "Content-Type:application/x-www-form-urlencoded" -H "$CRUMB" -X POST -d 'json={"name":"'"${NEW_NODE_NAME}"'","nodeDescription":"'"${DESC}"'","numExecutors":"'"${EXECUTORS}"'","remoteFS":"'"$WORK_DIR"'","labelString":"'"$LABELS"'","mode":"NORMAL","":["hudson.plugins.sshslaves.SSHLauncher","hudson.slaves.RetentionStrategy$Always"],"launcher":{"stapler-class":"hudson.plugins.sshslaves.SSHLauncher","$class":"hudson.plugins.sshslaves.SSHLauncher","host":"'"$SSH_HOST"'","credentialsId":"'"$CRED_ID"'","":"0","sshHostKeyVerificationStrategy":{"stapler-class":"hudson.plugins.sshslaves.verifiers.KnownHostsFileKeyVerificationStrategy","$class":"hudson.plugins.sshslaves.verifiers.KnownHostsFileKeyVerificationStrategy"},"port":"'"$SSH_PORT"'","javaPath":"","jvmOptions":"","prefixStartSlaveCmd":"","suffixStartSlaveCmd":"","launchTimeoutSeconds":"","maxNumRetries":"","retryWaitTime":"","tcpNoDelay":true,"workDir":""},"retentionStrategy":{"stapler-class":"hudson.slaves.RetentionStrategy$Always","$class":"hudson.slaves.RetentionStrategy$Always"},"nodeProperties":{"stapler-class-bag":"true"},"type":"hudson.slaves.DumbSlave","crumb":"'"$CRUMB"'"}' "${JENKINS_URL}/computer/doCreateItem?name=${NEW_NODE_NAME}&type=hudson.slaves.DumbSlave")

    #below api running in jenkins version 2.204.3 but crumb setting is not neccesary
    #RESPONSE=$(curl -L -s -o /dev/null -w "%{http_code}" -u "${USER_ID}:${TOKEN}" -H "Content-Type:application/x-www-form-urlencoded" -X POST -d 'json={"name":"'"${NEW_NODE_NAME}"'","nodeDescription":"'"${DESC}"'","numExecutors":"'"${EXECUTORS}"'","remoteFS":"'"$WORK_DIR"'","labelString":"'"$LABELS"'","mode":"NORMAL","":["hudson.plugins.sshslaves.SSHLauncher","hudson.slaves.RetentionStrategy$Always"],"launcher":{"stapler-class":"hudson.plugins.sshslaves.SSHLauncher","$class":"hudson.plugins.sshslaves.SSHLauncher","host":"'"$SSH_HOST"'","credentialsId":"'"$CRED_ID"'","":"0","sshHostKeyVerificationStrategy":{"stapler-class":"hudson.plugins.sshslaves.verifiers.KnownHostsFileKeyVerificationStrategy","$class":"hudson.plugins.sshslaves.verifiers.KnownHostsFileKeyVerificationStrategy"},"port":"'"$SSH_PORT"'","javaPath":"","jvmOptions":"","prefixStartSlaveCmd":"","suffixStartSlaveCmd":"","launchTimeoutSeconds":"","maxNumRetries":"","retryWaitTime":"","tcpNoDelay":true,"workDir":""},"retentionStrategy":{"stapler-class":"hudson.slaves.RetentionStrategy$Always","$class":"hudson.slaves.RetentionStrategy$Always"},"nodeProperties":{"stapler-class-bag":"true"},"type":"hudson.slaves.DumbSlave","Jenkins-Crumb":""}' "${JENKINS_URL}/computer/doCreateItem?name=${NEW_NODE_NAME}&type=hudson.slaves.DumbSlave")
   
    #MAKE NORMAL AGENT ---------------
    #create node(slave agent), that connect to the master by self
    #below api running to jenkins version 2.204.3, crumb setting is not neccesary
    RESPONSE=$(curl --cookie $COOKIEJAR -L -s -o /dev/null -w "%{http_code}" -u "${USER_ID}:${TOKEN}" -H "Content-Type:application/x-www-form-urlencoded" -X POST -d 'json={"name": "'"${NODE_NAME}"'", "nodeDescription":"'"$DESC"'","numExecutors":"'"$EXECUTORS"'","remoteFS":"'"$WORK_DIR"'","labelString":"'"$LABELS"'","mode":"NORMAL","":["hudson.plugins.sshslaves.SSHLauncher","hadson.slaves.RetentionStrategy$Always"],"launcher":{"stapler-class":"hudson.slaves.JNLPLauncher","$class":"hudson.slaves.JNLPLauncher"},"retentionStrategy":{"stapler-class":"hudson.slaves.RetentionStrategy$Always","$class":"hudson.slaves.RetentionStrategy$Always"},"nodeProperties":{"stapler-class-bag":"true"},"type":"hudson.slaves.DumbSlave","Jenkins-Crumb":""}' "${JENKINS_URL}/computer/doCreateItem?name=${NODE_NAME}&type=hudson.slaves.DumbSlave") 

    #create node(slave agent), that connect to the master by self
    #below api not running in jenkins version 2.204.3, another version try
    #RESPONSE=$(curl --cookie $COOKIEJAR -L -s -o /dev/null -w "%{http_code}" -u "${USER_ID}:${TOKEN}" -H "Content-Type:application/x-www-form-urlencoded" -H "$CRUMB" -X POST -d 'json={"name": "'"$NODE_NAME"'", "nodeDescription": "'"$DESC"'", "numExecutors": "'"$EXECUTORS"'","remoteFS":"'"$WORK_DIR"'","labelString":"'"$LABELS"'","mode": "NORMAL","": ["hudson.plugins.sshslaves.SSHLauncher","hudson.slaves.RetentionStrategy$Always"],"launcher":{"stapler-class":"hudson.slaves.JNLPLauncher","$class": "hudson.slaves.JNLPLauncher","retentionStrategy":{"stapler-class":"hudson.slaves.RetentionStrategy$Always","$class":"hudson.slaves.RetentionStrategy$Always"},"nodeProperties":{"stapler-class-bag":"true"},"type":"hudson.slaves.DumbSlave","crumb":"'"$CRUMB"'"}' "${JENKINS_URL}/computer/doCreateItem?name=${NODE_NAME}&type=hudson.slaves.DumbSlave")

    if [[ $RESPONSE == "200" ]]; then
      echo "$NODE_NAME node make Success"
    else
      echo "$NODE_NAME node make failed, response code: [${RESPONSE}]"
      exit 1
    fi

    RESULT=$(curl -s -u "${USER_ID}:${TOKEN}" ''${JENKINS_URL}/computer/${NEW_NODE_NAME}/ | grep 'command' | awk -F"</pre>" '{ print $1 }' | awk -F"</a>" '{ print $2 }')
    echo "${RESULT}" | sed 's/^ //' | sed 's/"//g' | tee -a $RESULT_FILE
    
    sleep 2
    ((START_NUMBER++))
  done
}


node_delete()
{
    get_crumb
    show_enable_crumb

    while [ ${START_NUMBER} -le ${END_NUMBER} ]
    do
        NEW_NODE_NAME=${NODE_NAME}-${START_NUMBER}

        # old version jenkins is crumb required!! 
        #RESULT=$(curl --cookie $COOKIEJAR -L -s -o /dev/null -w "%{http_code}" -u "${USER_ID}:${TOKEN}" -H "Content-Type:application/x-www-form-urlencoded" -H "$CRUMB" -X POST ''${JENKINS_URL}/computer/${NEW_NODE_NAME}/doDelete --data '')
    
        #new version jenkins is crub not required!!
        RESULT=$(curl --cookie $COOKIEJAR -L -s -o /dev/null -w "%{http_code}" -u "${USER_ID}:${TOKEN}" -H "Content-Type:application/x-www-form-urlencoded" -X POST ''${JENKINS_URL}/computer/${NEW_NODE_NAME}/doDelete --data '')
        echo $RESULT

        sleep 2
        ((START_NUMBER++))
    done
}

node_name_update()
{
    CONFIGURE=$(curl -s -w "%{http_code}" -u "${USER_ID}:${TOKEN}" -H "Accept: application/xml" ${JENKINS_URL}/computer/${OLD_NODE_NAME}/config.xml)
    CODE=${CONFIGURE:(-3)}
    echo "get configure code: $CODE"

    if [[ ${CODE} != "200" ]]; then
        echo "get configure not 200! continue next node"
    else
        CHAGE_DATA=${CONFIGURE:39:-3}
        #CHECK ENW HOST NAME AND OLD HOST NAME SAME
        before_hostname=$(echo $CHANGE_DATA | sed -ne '/name/{s/.*<name>\(.*\)<\/name>.*/\1/p;q;}')
        
        if [[ "${before_hostname}" == "${NEW_NODE_NAME}" ]]; then
            echo -e "\n-->>old host name and new host name is same, check new host name argument"
            usage
        fi

        CHANGE_DATA2=$(echo $CHANGE_DATA | sed -e 's/'"${OLD_NODE_NAME}"'/'"${NEW_NODE_NAME}"'/g')
        echo "change configure data: ${CHANGE_DATA2}"

        RESULT=$(curl --cookie $COOKIEJAR -L -s -o /dev/null -w "%{http_code}" -u "${USER_ID}:${TOKEN}" -H "Content-Type:application/xml" -H "Accept: application/xml" -H "$CRUMB" -d "${CHANGE_DATA2}" -X POST ${JENKINS_URL}/computer/${OLD_NODE_NAME}/config.xml)

        if [[ ${RESULT} == "200" ]]; then
            echo "${OLD_NODE_NAME} --> ${NEW_NODE_NAME} change success"
            RESULT=$(curl -s -u "${USER_ID}:${TOKEN}" ''${JENKINS_URL}/computer/${NEW_NODE_NAME}/ | grep 'command' | awk -F"</pre>" '{print $1}' | awk -F"</a>" '{print $2}')
            echo "${RESULT}" | sed 's/^ //' | sed 's/"//g' | tee -a $RESULT_FILE
        else
            echo "${OLD_NODE_NAME} --> ${NEW_NODE_NAME} change failed"
        
        fi
    fi
    sleep 2
}

node_rename()
{
    get_crumb
    show_enable_crumb

    echo $(date) | tee -a $RESULT_FILE

    if [ $# -ne 1 ]; then
        while [ $START_NUMBER -le $END_NUMBER ]
        do
            OLD_NODE_NAME=${NODE_NAME}-$START_NUMBER
            NEW_NODE_NAME=${WORK_DIR}-$START_NUMBER
            node_name_update
            ((START_NUMBER++))
        done
    else
        s_cnt=$(expr ${END_NUMBER}-${START_NUMBER}+1)
        e_cnt=$(expr ${NEW_END_NUMBER}-${NEW_START_NUMBER}+1)
        echo "number of nodes to change: $s_cnt"
        echo "number of new nodes: $e_cnt"

        if [ ${s_cnt} -ne ${e_cnt} ]; then
            echo -e "\n--->> The number of renamed nodes is different from the number of new name nodes"
            usage
        else
            if [ ${s_cnt} -eq ${e_cnt} ]; then
                while [ ${START_NUMBER} -le ${END_NUMBER} ]
                do 
                    OLD_NODE_NAME=${NODE_NAME}-$START_NUMBER
                    NEW_NODE_NAME=${WORK_DIR}-$START_NUMBER
                    node_name_update
                    ((START_NUMBER++))
                done
            fi
        fi
    fi
}

if [[ "$OPERATION" == "create" ]]; then
    node_create
elif [[ "$OPERATION" == "delete" ]]; then
    node_delete
elif [[ "$OPERATION" == "rename" ]]; then
    if [ $# -eq 5]; then
        node_rename
    else
        node_rename "asymmetry"
    fi
fi

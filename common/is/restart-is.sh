#!/bin/bash
# Copyright 2019 WSO2 Inc. (http://wso2.org)
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# ----------------------------------------------------------------------------
# Restart Identity Server
# ----------------------------------------------------------------------------

default_carbon_home=$(realpath ~/wso2is)
carbon_home=$default_carbon_home
default_waiting_time=100
waiting_time=$default_waiting_time
default_heap_size="2g"
heap_size="$default_heap_size"

function usage() {
    echo ""
    echo "Usage: "
    echo "$0  [-c <carbon_home>] [-w <waiting_time>]"
    echo ""
    echo "-c: The Identity server path."
    echo "-w: The waiting time in seconds until the server restart.."
    echo "-m: The heap memory size of Ballerina VM. Default: $default_heap_size."
    echo "-h: Display this help and exit."
    echo ""
}

while getopts "c:w:m:t:h" opts; do
    case $opts in
    c)
        carbon_home=${OPTARG}
        ;;
    w)
        waiting_time=${OPTARG}
        ;;
    m)
        heap_size=${OPTARG}
        ;;
    t)
        test_spec=${OPTARG}
        ;;
    h)
        usage
        exit 0
        ;;
    \?)
        usage
        exit 1
        ;;
    esac
done

if [ ! -d $carbon_home ]; then
    echo "Please provide the Identity Server path."
    exit 1
fi

if [[ -z $waiting_time ]]; then
    echo "Please provide the waiting time."
    exit 1
fi

if [[ -z $heap_size ]]; then
    echo "Please provide the heap size for the Identity Server."
    exit 1
fi

if [[ -z $test_spec ]]; then
    echo "Please provide the test specification"
    exit 1
fi

echo ""
echo "Cleaning up any previous log files..."
rm -rf $carbon_home/repository/logs/*

echo "Killing All Carbon Servers..."
killall java

echo "Enabling GC Logs..."
export JAVA_OPTS="-XX:+PrintGC -XX:+PrintGCDetails -Xloggc:${carbon_home}/repository/logs/gc.log"
JAVA_OPTS+=" -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath="${carbon_home}/repository/logs/heap-dump.hprof""
export JVM_MEM_OPTS="-Xms${heap_size} -Xmx${heap_size}"
echo "JAVA_OPTS: $JAVA_OPTS"
echo "JVM_MEM_OPTS: $JVM_MEM_OPTS"

file_path="$carbon_home/repository/conf/deployment.toml"

# Changing the server wide configurations for the test specs
if [ "$test_spec" == "23-oidc_auth_code_redirect_without_consent_retrieve_user_attributes" ]; then
    echo "Changing the server wide configurations for the test spec: $test_spec"
    echo "[authentication.consent] -> prompt=false"

    awk '/\[authentication.consent\]/ {flag=1;next} flag && /prompt=true/ {flag=0; print NR; exit}' "$file_path" | while read -r line_num
    do
        # If found, use sed to change prompt=true to prompt=false
        sed -i "${line_num}s|prompt=true|prompt=false|" "$file_path" || echo "Editing deployment.toml file failed!"
    done
else
    echo "Keeping default server wide configurations"

    awk '/\[authentication.consent\]/ {flag=1;next} flag && /prompt=false/ {flag=0; print NR; exit}' "$file_path" | while read -r line_num
    do
        # If found, use sed to change prompt=false to prompt=true
        sed -i "${line_num}s|prompt=false|prompt=true|" "$file_path" || echo "Editing deployment.toml file failed!"
    done
fi

echo "Restarting identity server..."
sh $carbon_home/bin/wso2server.sh restart

echo "Waiting $waiting_time seconds..."
sleep $waiting_time

echo "Finished starting identity server..."

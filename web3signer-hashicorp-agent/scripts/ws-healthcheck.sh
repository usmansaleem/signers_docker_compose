#!/bin/bash

max_wait_time=240 # 4 minutes
start_time=$(date +%s)

while true
do
    current_time=$(date -u +"%Y-%m-%d %H:%M:%S.%3N+00:00")
    response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9000/healthcheck)
    if [ $response -eq 200 ]
    then
        echo "[$current_time] Server returned 200, server is healthy."
        break
    elif [ $response -eq 503 ]
    then
        echo "[$current_time] Server returned 503, server is unhealthy."
        break
    elif [ $response -eq 000 ]
    then
        echo "[$current_time] Unable to connect to server, retrying in 2 seconds."
        sleep 2
    else
        echo "[$current_time] Server returned $response, retrying in 2 seconds"
        sleep 2
    fi

    current_time=$(date +%s)
    elapsed_time=$(($current_time - $start_time))

    if [ $elapsed_time -ge $max_wait_time ]
    then
        echo "Timed out after $max_wait_time seconds"
        break
    fi
done
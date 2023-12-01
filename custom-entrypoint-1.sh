#!/bin/bash

ip()
    {
        last_part="$1"
        upstream="postgresdb-stateful-$((last_part - 1)).postgres-headless-svc.default.svc.cluster.local"
        echo "the upstream url ==> $upstream"

        result=$(nslookup "$upstream" | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')


        echo "the result for nslookup $result"

        upstream_pod_ip=$(echo "$result" | awk 'END {print}')

         echo "$upstream_pod_ip"

    }

    initialize_db()
    {
            su -l postgres -c "/usr/pgsql-15/bin/initdb"
            su -l postgres -c "mv  /var/lib/pgsql/15/data/postgresql.conf /var/lib/pgsql/15/data/postgresql.conf.bkp"
            su -l postgres -c "cp /postgresql.conf /var/lib/pgsql/15/data/postgresql.conf"
            su -l postgres -c "mv  /var/lib/pgsql/15/data/pg_hba.conf /var/lib/pgsql/15/data/pg_hba.conf.bkp"
            su -l postgres -c "cp /pg_hba.conf /var/lib/pgsql/15/data/pg_hba.conf"
            su -l postgres -c "cp /repmgr.conf /var/lib/pgsql"
            ip_address=$PEER_POD_IP
            su -l postgres -c "sed -i "s/REPMGR_DB_HOST/$ip_address/g" /var/lib/pgsql/repmgr.conf"
            su -l postgres -c "/usr/pgsql-15/bin/pg_ctl -D /var/lib/pgsql/15/data -l /tmp/pg_logfile start"
            sleep 5

                su -l postgres -c "createuser -s repmgr"
                su -l postgres -c "createdb repmgr -O repmgr"

                su -l postgres -c "/usr/pgsql-15/bin/repmgr -f /var/lib/pgsql/repmgr.conf primary register"

    }


    primary()
    {
            standby_value=$(ip 2)
            #echo "the standby url ==> $standby_value"
            result=$(nslookup "$standby_value" | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
            #echo "the result for nslookup $result"
            standby_pod_ip=$(echo "$result" | awk 'END {print}')
            echo "the standby pod ip ==> $standby_pod_ip"
            ip_not_in_range="10.96.0.10"
            if [[ "$standby_pod_ip" == "$ip_not_in_range" ]]; then
                initialize_db
            else
                  sleep 80
                 secondary true
            fi

    }


    secondary()
    {
            isCalledFromPrimary="$1"
            #if iscalledfromprimary = true that means secondary is called from primary node and if the value of iscalledfromprimary is false that means it is called from main block

        #local upstream_pod_ip
        if [ $isCalledFromPrimary = true ]; then
                echo "Called from Primary"
            upstream_value=$(ip 2)
            echo "the upstream url ==> $upstream_value"
            result=$(nslookup "$upstream_value" | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')

            echo "the result for nslookup $result"
            upstream_pod_ip=$(echo "$result" | awk 'END {print}')
            echo "the upstream pod ip ==> $upstream_pod_ip"
            sleep 10
            new_node_name="standby-1"
            new_node_id=2
            su -l postgres -c "cp /repmgr.conf /var/lib/pgsql"
            su -l postgres -c "sed -i "s/^node_name=primary/node_name=$new_node_name/" /var/lib/pgsql/repmgr.conf"
            su -l postgres -c "sed -i "s/^node_id=1/node_id=$new_node_id/" /var/lib/pgsql/repmgr.conf"
            su -l postgres -c "sed -i "s/REPMGR_DB_HOST/$PEER_POD_IP/g" /var/lib/pgsql/repmgr.conf"
        else
                echo "Called from Main"
                upstream_value=$(ip 1)
                echo "the upstream url ==> $upstream_value"
                result=$(nslookup "$upstream_value" | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')

            echo "the result for nslookup $result"
            upstream_pod_ip=$(echo "$result" | awk 'END {print}')
            echo "the upstream pod ip ==> $upstream_pod_ip"
            sleep 10
        fi
        su -l postgres -c "/usr/pgsql-15/bin/repmgr -h $upstream_pod_ip -U repmgr -f /var/lib/pgsql/repmgr.conf standby clone --dry-run" &
        bg_command_pid=$!
        #echo "And the wait begins*******************"
        wait $bg_command_pid
        echo "The wait ends **************************"

        su -l postgres -c "/usr/pgsql-15/bin/repmgr -h $upstream_pod_ip -U repmgr -f /var/lib/pgsql/repmgr.conf standby clone" &
        clone_command_pid=$!

        wait $clone_command_pid

        su -l postgres -c "/usr/pgsql-15/bin/pg_ctl -D /var/lib/pgsql/15/data -l /tmp/pg_logfile start"

        su -l postgres -c "/usr/pgsql-15/bin/repmgr -f /var/lib/pgsql/repmgr.conf standby register"
        su -l postgres -c "/usr/pgsql-15/bin/repmgrd -f /var/lib/pgsql/repmgr.conf "
    }



    arrIN=(${POD_NAME//-/ })

    last_part="${arrIN[-1]}"

    echo "************** POD IDENTIFICATION ID: $last_part *****************************"

    if [ "$last_part" -gt 0 ]; then
        if [[ $last_part =~ ^[0-9]+$ ]]; then
            new_node_name="standby-$last_part"
            new_node_id=$((last_part + 1))

            su -l postgres -c "cp /repmgr.conf /var/lib/pgsql"
            su -l postgres -c "sed -i "s/^node_name=primary/node_name=$new_node_name/" /var/lib/pgsql/repmgr.conf"
            su -l postgres -c "sed -i "s/^node_id=1/node_id=$new_node_id/" /var/lib/pgsql/repmgr.conf"
            su -l postgres -c "sed -i "s/REPMGR_DB_HOST/$PEER_POD_IP/g" /var/lib/pgsql/repmgr.conf"
            secondary false
            tail -f /dev/null
        fi
    else
    echo "Within primary node *****************"
    primary
    tail -f /dev/null
    fi
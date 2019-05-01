#!/bin/bash

set -e

die() {
  echo "Failed on line $(caller)" >&2
}

trap die ERR

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
CONFIG_FILE=$DIR/letsencrypt-routeros.settings

declare -a ROUTEROS_HOSTS

if [[ -f "$CONFIG_FILE" ]]; then
        source $CONFIG_FILE
fi

if [[ -z $1 ]] || [[ -z $2 ]] || [[ -z $3 ]] || [[ -z $4 ]]; then
        echo -e "Usage: $0 or $0 [RouterOS User] [RouterOS Host] [SSH Port] [Domain]\n"
else
        ROUTEROS_USER=$1
        ROUTEROS_HOST=$2
        ROUTEROS_SSH_PORT=$3
        DOMAIN=$4
fi

if [[ ! -z $ROUTEROS_HOST ]]; then
        ROUTEROS_HOSTS=($ROUTEROS_HOST)
fi

if [[ -z $ROUTEROS_USER || -z $ROUTEROS_HOSTS || -z $ROUTEROS_SSH_PORT || -z $DOMAIN ]]; then
        echo "Check the config file $CONFIG_FILE or start with params: $0 [RouterOS User] [RouterOS Host] [SSH Port] [Domain]"
        echo "Please avoid spaces"
        exit 1
fi

if [[ ! -f $CERTIFICATE && ! -f $KEY ]]; then
        echo -e "\nFile(s) not found:\n$CERTIFICATE\n$KEY\n"
        echo "Please create certificate and key first !"
        exit 1
fi

#Create alias for RouterOS command
routeros() {
        ssh $ROUTEROS_USER@$ROUTEROS_HOST -p $ROUTEROS_SSH_PORT $@
}

for ROUTEROS_HOST in ${ROUTEROS_HOSTS[@]}; do
        #Check connection to RouterOS
        routeros /system resource print
        RESULT=$?

        if [[ ! $RESULT == 0 ]]; then
                echo -e "\nError in: $ROUTEROS_HOST"
                echo "More info: https://wiki.mikrotik.com/wiki/Use_SSH_to_execute_commands_(DSA_key_login)"
                exit 1
        else
                echo -e "\nConnection to $ROUTEROS_HOST Successful!\n" 
        fi

done

for ROUTEROS_HOST in ${ROUTEROS_HOSTS[@]}; do
        echo -e "[$ROUTEROS_HOST] - Remove previous certificate" 
        # Remove previous certificate
        routeros /certificate remove [find name=$DOMAIN.pem_0]

        # Create Certificate
        # Delete Certificate file if the file exist on RouterOS
        routeros /file remove $DOMAIN.pem > /dev/null
        # Upload Certificate to RouterOS
        echo -e "[$ROUTEROS_HOST] - Upload new certificate" 
        scp -q -P $ROUTEROS_SSH_PORT  "$CERTIFICATE" "$ROUTEROS_USER"@"$ROUTEROS_HOST":"$DOMAIN.pem"
done

sleep 2

for ROUTEROS_HOST in ${ROUTEROS_HOSTS[@]}; do
        echo -e "[$ROUTEROS_HOST] Import new certificate" 
        # Import Certificate file
        routeros /certificate import file-name=$DOMAIN.pem passphrase=\"\"
        # Delete Certificate file after import
        routeros /file remove $DOMAIN.pem

        # Create Key
        echo -e "[$ROUTEROS_HOST] Remove previous private key" 
        # Delete Certificate file if the file exist on RouterOS
        routeros /file remove $KEY.key > /dev/null
        echo -e "[$ROUTEROS_HOST] Upload new private key" 
        # Upload Key to RouterOS
        scp -q -P $ROUTEROS_SSH_PORT "$KEY" "$ROUTEROS_USER"@"$ROUTEROS_HOST":"$DOMAIN.key"
done

sleep 2

for ROUTEROS_HOST in ${ROUTEROS_HOSTS[@]}; do
        echo -e "[$ROUTEROS_HOST] Import new private key" 
        # Import Key file
        routeros /certificate import file-name=$DOMAIN.key passphrase=\"\"
        # Delete Certificate file after import
        routeros /file remove $DOMAIN.key

        # Setup Certificate to SSTP Server
        routeros /ip service set certificate=$DOMAIN.pem_0 www-ssl
        #$routeros /interface sstp-server server set certificate=$DOMAIN.pem_0
done

exit 0

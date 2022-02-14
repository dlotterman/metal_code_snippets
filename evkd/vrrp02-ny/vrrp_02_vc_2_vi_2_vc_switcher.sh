#!/bin/bash

APIKEY="UUIDSTRING"
CONNID="3f768ff0-c795-4380-a5f2-a4a07b7f6711"
SECPORT="ad9132ec-6567-4297-9dd4-770ca6375510"

#PRIVC is the VC where the VLAN "normally" lives, so where it is currently active
PRIVC="5fc44a7c-0d3a-4c50-ac46-f1e201cc9feb"
SECVC="aeadc313-a6b4-4204-92b4-a634c9e1c1ee"
PRIVLAN="2084"
SECVLAN="1529"

STARTTIME=$SECONDS


# https://www.urbanautomaton.com/blog/2014/09/09/redirecting-bash-script-output-to-syslog/

readonly SCRIPT_NAME=$(basename $0)

log() {
  echo "$@"
  logger -p user.notice -t $SCRIPT_NAME "$@"
}

err() {
  echo "$@" >&2
  logger -p user.error -t $SCRIPT_NAME "$@"
}

log " - stdout and stderr also sent to syslog where timestamps are"
log "this script is going to try to do the following:"
log "take VLAN $PRIVLAN attached to primary VC $PRIVC"
log "and swap that $PRIVLAN to secondary VC $SECVC"
log "and then swap the $SECVLAN onto the $PRIVC"

SECPORT_STATUS_RESP=$(curl -s -X GET \
--header 'Accept: application/json' \
--header 'X-Auth-Token: '$APIKEY  \
'https://api.equinix.com/metal/v1/connections/'$CONNID'/ports/'$SECPORT)

SECPORT_STATUS=$(echo $SECPORT_STATUS_RESP | jq -r .status)
if [ $SECPORT_STATUS == "active" ]; then
    log " - Sanity check API call success, proceeding"
    log " - Secondary port active / appears healthy, proceeding"
else
    err " - Could not make sanity check API port status call, either API isn't reachable from this host or is misbehaving, aborting"
    exit 1
fi

# Placed in dev shm to loose file on reboot
if [ ! -f /dev/shm/switcher.armed ]; then
    err " - /dev/shm/switcher.armed file does not exist. touch file to arm switcher, aborting"
    err "Writing -500 to VRRP control file /tmp/vrrp_VC_1_VI_1.trackfile to induce fault state to avoid split brain, aborting"
    echo "-500" > /tmp/vrrp_VC_2_VI_2.trackfile
    exit 1
else
        log " - /dev/shm/switcher.armed file found, proceeding"
fi

SW_DATE=$(date +"%Y-%m-%d_%H%M%S")

# Unassociate PRIVC from PRIVLAN
PRIVC_UNASS_RESP=$(curl -s \
-X PUT \
--header "Content-Type: application/json" \
--header 'Accept: application/json' \
--header 'X-Auth-Token: '$APIKEY  \
-d '{"vnid": "", "description": "EVLD_managed","tags":["EVLD_managed"]}' \
'https://api.equinix.com/metal/v1/virtual-circuits/'$PRIVC)

PRIVC_STATUS=$(echo $PRIVC_UNASS_RESP | jq -r .status)
if [ $PRIVC_STATUS == "waiting_on_customer_vlan" ]; then
    PRIVC_PASS_LOOP=true
    log "Attempt to unassociate Primary VC $PRIVC succesful, proceeding"
elif [ $PRIVC_STATUS == "deactivating" ]; then
    log "Primary VC $PRIVC still deactivating, looping"
    PRIVC_PASS_LOOP=false
else
    err "Attempt to unassociate Primary VC $PRIVC appears to have failed, aborting. VC status $PRIVC_UNASS_RESP"
    exit 1
fi

# The unassign requests need to be state looped
# Before going on to assign the next VLAN
# The variability is significant enough
# that if you just sleep your oppertunity cose
# is too high.
for ATTEMPT in {1..40}; do 
    if [ $PRIVC_PASS_LOOP == true ]; then
        break
    fi
    PRIVC_UNASS_RESP=$(curl -s \
    -X GET \
    --header 'Accept: application/json' \
    --header 'X-Auth-Token: '$APIKEY  \
    'https://api.equinix.com/metal/v1/virtual-circuits/'$PRIVC)

    PRIVC_STATUS=$(echo $PRIVC_UNASS_RESP | jq -r .status)

    if [ $PRIVC_STATUS == "waiting_on_customer_vlan" ]; then
        log "Attempt to unassociate Primary VC $PRIVC succesful, proceeding"
        break
    elif [ $PRIVC_STATUS == "deactivating" ]; then
        log "Primary VC $PRIVC still deactivating, looping"
        sleep 1
        continue
    elif [ $ATTEMPT = 40 ]; then
        err "Timing out on disassociating $PRIVC after 15 seconds"
        exit 1
    else
        err "Attempt to unassociate Primary VC $PRIVC appears to have failed, aborting. VC status $PRIVC_UNASS_RESP"
        exit 1
    fi
done

# Unassociate SECVC from SECVLAN
SECVC_UNASS_RESP=$(curl -s \
-X PUT \
--header "Content-Type: application/json" \
--header 'Accept: application/json' \
--header 'X-Auth-Token: '$APIKEY  \
-d '{"vnid": "", "description": "EVLD_managed","tags":["EVLD_managed"]}' \
'https://api.equinix.com/metal/v1/virtual-circuits/'$SECVC)

SECVC_STATUS=$(echo $SECVC_UNASS_RESP | jq -r .status)

if [ $SECVC_STATUS == "waiting_on_customer_vlan" ]; then
    SECVC_PASS_LOOP=true
    log "Attempt to unassociate Secondary VC $SECVC succesful, proceeding"
elif [ $SECVC_STATUS == "deactivating" ]; then
    SECVC_PASS_LOOP=false
    log "Secondary VC $SECVC still deactivating, looping"
else
    err "Attempt to unassociate Secondary VC $SECVC appears to have failed, aborting. VC status $SECVC_UNASS_RESP"
    exit 1
fi

for ATTEMPT in {1..15}; do 
    if [ $SECVC_PASS_LOOP = true ]; then
        break
    fi
    SECVC_UNASS_RESP=$(curl -s \
    -X GET \
    --header 'Accept: application/json' \
    --header 'X-Auth-Token: '$APIKEY  \
    'https://api.equinix.com/metal/v1/virtual-circuits/'$SECVC)

    SECVC_STATUS=$(echo $SECVC_UNASS_RESP | jq -r .status)

    if [ $SECVC_STATUS == "waiting_on_customer_vlan" ]; then
        log "Attempt to unassociate Secondary VC $SECVC succesful, proceeding"
        break
    elif [ $SECVC_STATUS == "deactivating" ]; then
        log "Secondary VC $SECVC still deactivating, looping"
        sleep 1
        continue
    elif [ $ATTEMPT = 40 ]; then
        err "Timing out on disassociating $SECVC after 15 seconds"
        exit 1
    else
        err "Attempt to unassociate Secondary VC $SECVC appears to have failed, aborting. VC status $SECVC_UNASS_RESP"
        exit 1
    fi
done

# We don't need to loop to check in with state for these
# Because we just check that we have the right output on the way out the door
# The VC will activate as fast as it can without us checking on it

# Associate PRIVC with SECVLAN

PRIVC_SECVLAN_ASS_RESP=$(curl -s \
-X PUT \
--header "Content-Type: application/json" \
--header 'Accept: application/json' \
--header 'X-Auth-Token: '$APIKEY  \
-d '{"vnid": "'$SECVLAN'", "description": "EVLD_touched'$SW_DATE'","name": "EVLD_touched'$SW_DATE'","tags":["EVLD_managed"]}' \
'https://api.equinix.com/metal/v1/virtual-circuits/'$PRIVC)

PRIVC_SECVLAN_STATUS=$(echo $PRIVC_SECVLAN_ASS_RESP | jq -r .status)

if [ $PRIVC_SECVLAN_STATUS == "active" ]; then
    log "Attempt to associate Primary VC $PRIVC with Secondary VLAN $SECVLAN succesful, proceeding"
elif [ $PRIVC_SECVLAN_STATUS == "activating" ]; then
    log "Primary VC $PRIVC with Secondary VLAN $SECVLAN still activating, proceeding"
else
    err "Attempt to associate Primary VC $PRIVC with Secondary VLAN $SECLVAN appears to have failed, aborting. VC status is $PRIVC_SECVLAN_ASS_RESP"
    exit 1
fi

# Associate SECVC with PRIVLAN

SECVC_PRIVLAN_ASS_RESP=$(curl -s \
-X PUT \
--header "Content-Type: application/json" \
--header 'Accept: application/json' \
--header 'X-Auth-Token: '$APIKEY  \
-d '{"vnid": "'$PRIVLAN'", "description": "EVLD_touched'$SW_DATE'","name": "EVLD_touched'$SW_DATE'","tags":["EVLD_managed"]}' \
'https://api.equinix.com/metal/v1/virtual-circuits/'$SECVC)

SECVC_PRIVLAN_STATUS=$(echo $SECVC_PRIVLAN_ASS_RESP | jq -r .status)

if [ $SECVC_PRIVLAN_STATUS == "active" ]; then
    log "Attempt to associate Secondary VC $SECVC with Primary VLAN $PRIVLAN succesful, proceeding"
elif [ $SECVC_PRIVLAN_STATUS == "activating" ]; then
    log "Secondary VC $SECVC with Primary VLAN $PRIVLAN still activating, proceeding"
else
   err "Attempt to associate Secondary VC $SECVC with Primary VLAN $PRIVLAN appears to have failed, aborting. VC status is $SECVC_PRIVLAN_ASS_RESP"
    exit 1
fi

log "Writing -500 to VRRP control file /tmp/vrrp_VC_2_VI_2.trackfile to induce fault state to avoid split brain, proceeding"

echo -500 > /tmp/vrrp_VC_2_VI_2.trackfile

ENDTIME=$(( SECONDS - $STARTTIME ))

log "Work work complete in $ENDTIME seconds, exiting"

exit


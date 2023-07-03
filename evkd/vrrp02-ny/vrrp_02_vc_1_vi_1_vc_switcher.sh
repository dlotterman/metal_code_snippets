#!/bin/bash

APIKEY="UUIDSTRING"
CONNID="06726413-c565-4173-82be-9a9562b9a69b"
SECPORT="963471e8-c815-4055-93b6-74092227d65c"

#PRIVC is the VC where the VLAN "normally" lives, so where it is currently active
PRIVC="486b414a-60a7-4767-aa84-340ca9bc14d5"
SECVC="0863c2f0-5724-4ee1-9ac4-eb3d13f83b12"
PRIVLAN="2084"
SECVLAN="1529"

STARTTIME=$SECONDS

# Trick to send output to logger
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
--header 'X-Auth-Token: '$APIKEY \
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
    echo "-500" > /tmp/vrrp_VC_1_VI_1.trackfile
    exit 1

else
        log " - /dev/shm/switcher.armed file found, proceeding"
fi

SW_DATE=$(date +"%Y-%m-%d_%H%M%S")

log "Unassociating VLANs"

# Unassociate PRIVC from PRIVLAN
PRIVC_UNASS_RESP=$(curl -s \
-X PUT \
--header "Content-Type: application/json" \
--header 'Accept: application/json' \
--header 'X-Auth-Token: '$APIKEY \
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

# Unassociate SECVC from SECVLAN
SECVC_UNASS_RESP=$(curl -s \
-X PUT \
--header "Content-Type: application/json" \
--header 'Accept: application/json' \
--header 'X-Auth-Token: '$APIKEY \
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

# The unassign requests need to be state looped
# Before going on to assign the next VLAN
# The variability is significant enough
# that if you just sleep your oppertunity cose
# is too high.
# We also want to loop after making the unassociate call first
# for both VC's to start that as quickly as possible

for ATTEMPT in {1..40}; do
    if [ $PRIVC_PASS_LOOP == true ]; then
        break
    fi
    PRIVC_UNASS_RESP=$(curl -s \
    -X GET \
    --header 'Accept: application/json' \
    --header 'X-Auth-Token: '$APIKEY \
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

### Looping control from # Unassociate SECVC from SECVLAN
for ATTEMPT in {1..15}; do
    if [ $SECVC_PASS_LOOP = true ]; then
        break
    fi
    SECVC_UNASS_RESP=$(curl -s \
    -X GET \
    --header 'Accept: application/json' \
    --header 'X-Auth-Token: '$APIKEY \
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
--header 'X-Auth-Token: '$APIKEY \
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
--header 'X-Auth-Token: '$APIKEY \
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

log "Writing -500 to VRRP control file /tmp/vrrp_VC_1_VI_1.trackfile to induce fault state to avoid split brain, proceeding"


echo -500 > /tmp/vrrp_VC_1_VI_1.trackfile

ENDTIME=$(( SECONDS - $STARTTIME ))

log "Work work complete in $ENDTIME seconds, exiting"

exit

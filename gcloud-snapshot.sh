#!/usr/bin/env bash
export PATH=$PATH:/usr/local/bin/:/usr/bin




###############################
##                           ##
## INITIATE SCRIPT FUNCTIONS ##
##                           ##
##  FUNCTIONS ARE EXECUTED   ##
##   AT BOTTOM OF SCRIPT     ##
##                           ##
###############################


#
# DOCUMENTS ARGUMENTS
#

usage() {
  echo -e "\nUsage: $0 -p <project> [-d <days>]" 1>&2
  echo -e "\nOptions:\n"
  echo -e "    -p    Project name."
  echo -e "          [REQUIRED]"
  echo -e "    -d    Number of days to keep snapshots.  Snapshots older than this number deleted."
  echo -e "          Default if not set: 7 [OPTIONAL]"
  echo -e "    -f    Filter devices list."
  echo -e "          Default if not set: 'labels.auto-snapshot = true' [OPTIONAL]"
  echo -e "\n"
  exit 1
}


#
# GETS SCRIPT OPTIONS AND SETS GLOBAL VAR $OLDER_THAN
#

setScriptOptions()
{
    while getopts ":d:p:f:" o; do
      case "${o}" in
        d)
          opt_d=${OPTARG}
          ;;

        p)
          opt_p=${OPTARG}
          ;;
        f)
          opt_f=${OPTARG}
          ;;
        *)
          usage
          ;;
      esac
    done
    shift $((OPTIND-1))

    if [[ -n $opt_p ]];then
      PROJECT_ID=$opt_p
    else
      >&2 echo "Invalid project name"
      exit 1
    fi

    if [[ -n $opt_d ]];then
      OLDER_THAN=$opt_d
    else
      OLDER_THAN=7
    fi

    if [[ -n $opt_f ]];then
      DEVICE_LIST_FILTER=$opt_f
    else
      DEVICE_LIST_FILTER=${DEVICE_LIST_FILTER:-'labels.auto-snapshot = true'}
    fi
}


#
# RETURNS LIST OF DEVICES
#
# input: ${INSTANCE_NAME}
#

getDeviceList()
{
    echo "$(gcloud --project=$PROJECT_ID compute disks list --filter "$DEVICE_LIST_FILTER" --format='value(name)')"
}


#
# RETURN ZONE OF DEVISE
#
# input: ${DEVISE_NAME}
#

getDeviceZone()
{
    echo "$(gcloud --project=$PROJECT_ID compute disks list --filter name="$1" --format='value(zone)')"
}


#
# RETURNS SNAPSHOT NAME
#

createSnapshotName()
{
    # create snapshot name
    local name="gcas-$1-$2"

    # google compute snapshot name cannot be longer than 62 characters
    local name_max_len=62

    # check if snapshot name is longer than max length
    if [ ${#name} -ge ${name_max_len} ]; then

        # work out how many characters we require - prefix + device id + timestamp
        local req_chars="gcas--$2"

        # work out how many characters that leaves us for the device name
        local device_name_len=`expr ${name_max_len} - ${#req_chars}`

        # shorten the device name
        local device_name=${1:0:device_name_len}

        # create new (acceptable) snapshot name
        name="gcas-${device_name}-$2" ;

    fi

    echo -e ${name}
}


#
# CREATES SNAPSHOT AND RETURNS OUTPUT
#
# input: ${DEVICE_NAME}, ${SNAPSHOT_NAME}, ${INSTANCE_ZONE}
#

createSnapshot()
{
    echo -e "$(gcloud --project=$PROJECT_ID compute disks snapshot $1 --snapshot-names $2 --zone $3)"
}


#
# GETS LIST OF SNAPSHOTS AND SETS GLOBAL ARRAY $SNAPSHOTS
#
# input: ${SNAPSHOT_REGEX}
# example usage: getSnapshots "(gcas-.*${INSTANCE_ID}-.*)"
#

getSnapshots()
{
    # create empty array
    SNAPSHOTS=()

    # get list of snapshots from gcloud for this device
    local gcloud_response="$(gcloud --project=$PROJECT_ID compute snapshots list --filter="name~'"$1"'" --uri)"

    # loop through and get snapshot name from URI
    while read line
    do
        # grab snapshot name from full URI
        snapshot="${line##*/}"

        # add snapshot to global array
        SNAPSHOTS+=(${snapshot})

    done <<< "$(echo -e "$gcloud_response")"
}


#
# RETURNS SNAPSHOT CREATED DATE
#
# input: ${SNAPSHOT_NAME}
#

getSnapshotCreatedDate()
{
    local snapshot_datetime="$(gcloud --project=$PROJECT_ID compute snapshots describe $1 | grep "creationTimestamp" | cut -d " " -f 2 | tr -d \')"

    #  format date
    echo -e "$(date -d ${snapshot_datetime%?????} +%Y%m%d)"

    # Previous Method of formatting date, which caused issues with older Centos
    #echo -e "$(date -d ${snapshot_datetime} +%Y%m%d)"
}


#
# RETURNS DELETION DATE FOR ALL SNAPSHOTS
#
# input: ${OLDER_THAN}
#

getSnapshotDeletionDate()
{
    echo -e "$(date -d "-$1 days" +"%Y%m%d")"
}


#
# RETURNS ANSWER FOR WHETHER SNAPSHOT SHOULD BE DELETED
#
# input: ${DELETION_DATE}, ${SNAPSHOT_CREATED_DATE}
#

checkSnapshotDeletion()
{
    if [ $1 -ge $2 ]

        then
            echo -e "1"
        else
            echo -e "2"

    fi
}


#
# DELETES SNAPSHOT
#
# input: ${SNAPSHOT_NAME}
#

deleteSnapshot()
{
    echo -e "$(gcloud --project=$PROJECT_ID compute snapshots delete $1 -q)"
}


logTime()
{
    local datetime="$(date +"%Y-%m-%d %T")"
    echo -e "$datetime: $1"
}


#######################
##                   ##
## WRAPPER FUNCTIONS ##
##                   ##
#######################


createSnapshotWrapper()
{
    # log time
    logTime "Start of createSnapshotWrapper"

    # get date time
    DATE_TIME="$(date "+%s")"

    # get a list of all the devices
    DEVICE_LIST=$(getDeviceList)

    # create the snapshots
    echo "${DEVICE_LIST}" | while read DEVICE_NAME
    do
        # create snapshot name
        SNAPSHOT_NAME=$(createSnapshotName ${DEVICE_NAME} ${DATE_TIME})

        # get devise zone
        ZONE=$(getDeviceZone ${DEVICE_NAME})

        # create the snapshot
        OUTPUT_SNAPSHOT_CREATION=$(createSnapshot ${DEVICE_NAME} ${SNAPSHOT_NAME} ${ZONE})
    done
}

deleteSnapshotsWrapper()
{
    # log time
    logTime "Start of deleteSnapshotsWrapper"

    # get the deletion date for snapshots
    DELETION_DATE=$(getSnapshotDeletionDate "${OLDER_THAN}")

    # get list of snapshots for regex - saved in global array
    getSnapshots "gcas-.*"

    # loop through snapshots
    for snapshot in "${SNAPSHOTS[@]}"
    do
        # get created date for snapshot
        SNAPSHOT_CREATED_DATE=$(getSnapshotCreatedDate ${snapshot})

        # check if snapshot needs to be deleted
        DELETION_CHECK=$(checkSnapshotDeletion ${DELETION_DATE} ${SNAPSHOT_CREATED_DATE})

        # delete snapshot
        if [ "${DELETION_CHECK}" -eq "1" ]; then
           OUTPUT_SNAPSHOT_DELETION=$(deleteSnapshot ${snapshot})
        else
           echo "No need to delete ${snapshot}"
        fi

    done
}




##########################
##                      ##
## RUN SCRIPT FUNCTIONS ##
##                      ##
##########################

# log time
logTime "Start of Script"

# set options from script input / default value
setScriptOptions "$@"

# create snapshot
createSnapshotWrapper

# delete snapshots older than 'x' days
deleteSnapshotsWrapper

# log time
logTime "End of Script"

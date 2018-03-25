CUID=${1:-$(id -u)}
CGID=${2:-$(id -g)}
CUSER=${3:-www-data}
CGROUP=${4:-www-data}
# COMMAND_PREFIX may be used to run inside or outside container
# it can be docker-compose exec -T {containername} or empty string to run locally
COMMAND_PREFIX=${5:-'docker-compose exec -T php '}
echo Setting User ${CUSER} = ${CUID} and Group ${CGROUP} = ${CGID}

if [[ (${CUID} == 0) || (${CGID} == 0) ]]; then
    echo It is prohibited to change UID or GID for user 0
elif [[ $(${COMMAND_PREFIX} grep -c ${CUSER}:x:${CUID}:${CGID} /etc/passwd) == 1 ]]; then
    echo ${CUSER} already is ${CUID}:${CGID}. No needs to modify users inside container.
else
    set -x
    # Install shadow if it is not exeists as we need usermod and groupmod
    # For now it is done for Alpine's APK, and not sure is it needed for other OS
    if [[ (($(${COMMAND_PREFIX} which groupmod) == "") && ($(${COMMAND_PREFIX} which apk) != "")) ]]; then
        ${COMMAND_PREFIX} apk add --no-cache shadow
    fi;

    # groupname for group with GID=CGID
    EXISTENT_GROUP_NAME=$(${COMMAND_PREFIX} getent group ${CGID} | cut -d: -f1)
    # username for user with UID=CUID
    EXISTENT_USER_NAME=$(${COMMAND_PREFIX} getent passwd ${CUID} | cut -d: -f1)
    # Actual UID and GID for CUSER
    EXISTENT_UID=$(${COMMAND_PREFIX} getent passwd ${CUSER} | cut -d: -f3)
    EXISTENT_GID=$(${COMMAND_PREFIX} getent passwd ${CGROUP} | cut -d: -f3)

    # Moving existent GID to new one, if any exists
    if [[ (${EXISTENT_GROUP_NAME} != ${CGROUP}) && (${EXISTENT_GROUP_NAME} != '') ]]; then
        # Getting next free GID bigger, then 1000
        NEW_GID=$(${COMMAND_PREFIX} awk -F: '{gid[$3]=1}END{for(x=1000; x<=10000; x++) {if(gid[x] != ""){}else{print x; exit;}}}' /etc/group)
        ${COMMAND_PREFIX} groupmod ${EXISTENT_GROUP_NAME} -g ${NEW_GID}
        ${COMMAND_PREFIX} find / -group ${CGID} -exec chgrp -h ${NEW_GID} {} \;
        echo Changed GID: ${CGID} for user ${EXISTENT_GROUP_NAME} to GID: ${NEW_GID}
    fi
    # Moving existent UID to new one, if any exists
    if [[ (${EXISTENT_USER_NAME} != ${CUSER}) && (${EXISTENT_USER_NAME} != '') ]]; then
        # Getting next free UID bigger, then 1000
        NEW_UID=$(${COMMAND_PREFIX} awk -F: '{uid[$3]=1}END{for(x=1000; x<=10000; x++) {if(uid[x] != ""){}else{print x; exit;}}}' /etc/passwd)
        ${COMMAND_PREFIX} usermod ${EXISTENT_USER_NAME} -u ${NEW_UID}
        ${COMMAND_PREFIX} find / -user ${CUID} -exec chown -h ${NEW_UID} {} \;
        echo Changed UID: ${CUID} for user ${EXISTENT_USER_NAME} to UID: ${NEW_UID}
    fi
    if [[ (${CGID} != ${EXISTENT_GID}) ]]; then
        ${COMMAND_PREFIX} groupmod ${CGROUP} -g ${CGID}
        ${COMMAND_PREFIX} find / -group ${EXISTENT_GID} -exec chgrp -h ${CGID} {} \;
        echo ${CUSER} group set to ${CGID}.
    fi
    if [[ (${CUID} != ${EXISTENT_UID}) ]]; then
        ${COMMAND_PREFIX} usermod ${CUSER} -u ${CUID}
        ${COMMAND_PREFIX} find / -user ${EXISTENT_UID} -exec chown -h ${CUID} {} \;
        echo ${CUSER} user set to ${CUID}.
    fi
    set +x
fi;

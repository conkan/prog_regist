#!/bin/bash
NAME='apache4pgreg'
PSET='-p 9001:80'
RUNOPT='-d --restart=always'
LOGMNT='-v /var/log/http4pgreg:/var/log/http'
DEVMNT=''
# 開発時はgit checkout先をmountする
DEVMNT='-v '$(pwd)'/pgreg/prog_regist:/usr/local/apache2/htdocs/prog_regist'

STAT=`docker inspect $NAME | grep Status | awk -F'"' '{print $4}'`
if [ ${STAT} ]; then
    if [ ${STAT} == 'running' ]; then
        docker stop ${NAME}
    fi
    docker rm ${NAME}
fi
docker run ${RUNOPT} --name ${NAME} ${PSET} ${LOGMNT} ${DEVMNT} conkan/apache4pgreg

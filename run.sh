#!/bin/bash
NAME='apache4pgreg'
# nginxリバースプロキシをホスト上で動かす場合、localhostにのみ9001を公開
PSET='-p 127.0.0.1:9001:80'
# 同じホスト上でconkan_programコンテナを動かし直接WebAPIを呼び出す場合、連携
LNKOPT='--link conkanprog'
RUNOPT='-d --restart=always'
LOGMNT='-v /var/log/http4pgreg:/var/log/http'
# 本番系は、run.sh product で起動
if [ "$1" = "product" ] ; then
    DEVMNT=''
    ## 正式リリースしたらタグを指定する
    # IMGTAG=':2.0.0'
else
    # 開発時はgit checkout先をmountする
    DEVMNT='-v '$(pwd)'/pgreg/program_entry:/usr/local/apache2/htdocs/program_entry'
fi

STAT=`docker inspect $NAME | grep Status | awk -F'"' '{print $4}'`
if ! [ ${STAT} ]; then
    STAT=`docker inspect $NAME | grep Running | awk '{print $2}'`
    if [ ${STAT} ]; then
        if [ ${STAT} == 'true,' ]; then
            STAT='running'
        fi
    fi
fi
if [ ${STAT} ]; then
    if [ ${STAT} == 'running' ]; then
        docker stop ${NAME}
    fi
    docker rm ${NAME}
fi
ALLOPT="${RUNOPT} --name ${NAME} ${PSET} ${LOGMNT} ${DEVMNT} ${LNKOPT}"
docker run ${ALLOPT} conkan/apache4pgreg${IMGTAG}

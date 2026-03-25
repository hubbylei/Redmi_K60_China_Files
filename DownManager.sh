#!/usr/bin/bash

headers=$HEADERS
KSU_ver=$KSU
WorkDir=$WORKSPACE

json_workflow_runs=$(curl -skL -H "${headers}" "https://api.github.com/repos/tiann/KernelSU/actions/runs")
total=$(echo ${json_workflow_runs} | jq .total_count)
pages=$(($total / 30))
if [ $(($total % 30)) -gt 0 ];then
    pages=$(($pages + 1))
fi

i=0
while [ $i -lt $pages ]
do
    json_workflow_runs=$(curl -skL -H "${headers}" "https://api.github.com/repos/tiann/KernelSU/actions/runs?page=${i}")
    len=$(echo ${json_workflow_runs} | jq '.workflow_runs | length')
    j=0
    while [ $j -lt $len ]
    do
        name=$(echo ${json_workflow_runs} | jq -r .workflow_runs[${j}].name)
        if [ "${name}" == "Build Manager" ];then
            artifacts_url=$(echo ${json_workflow_runs} | jq -r .workflow_runs[$j].artifacts_url)
            json_artifacts_url=$(curl -skL -H "${headers}" ${artifacts_url})
            archive_url=$(echo ${json_artifacts_url} | jq '.artifacts[] | select(.name == "manager")' | jq -r .archive_download_url)
            if [ ! -z ${archive_url} ];then
                curl -skL -H "${headers}" -o "${WorkDir}/manager.zip" "${archive_url}"
                unzip -o "${WorkDir}/manager.zip" -d "${WorkDir}" > /dev/null
                if [ $? -ne 0 ];then
                    continue
                fi
                rm -f "${WorkDir}/manager.zip"
                apk=$(ls *.apk)
                apk_ver=$(echo ${apk} | sed 's/^.*_\(.*\)-.*/\1/')
                if [ "${apk_ver}" == "${KSU_ver}" ];then
                    echo "Manager: ${apk}"
                    break
                else
                    rm -f "${WorkDir}/${apk}"
                    apk=""
                fi
            fi
        fi
        let j++
    done
    if [ "${apk}" != "" ];then
        break
    fi
    let i++
done

if [ "${apk}" == "" ];then
    json_latest=$(curl -skL -H "${headers}" "https://api.github.com/repos/tiann/KernelSU/releases/latest")
    json_asset=$(echo ${json_latest} | jq '.assets[] | select(.content_type == "application/vnd.android.package-archive")')
    apk_name=$(echo ${json_asset} | jq -r .name)
    apk_url=$(echo ${json_asset} | jq -r .browser_download_url)
    echo "Manager: ${apk_name}"
    curl -skL -H "${headers}" -o "${WorkDir}/${apk_name}" "${apk_url}"
fi
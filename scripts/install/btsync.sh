#!/bin/bash
#
# [Quick Box :: Install Resilio Sync (BTSync) package]
#
# GITHUB REPOS
# GitHub _ packages  :   https://github.com/QuickBox/quickbox_packages
# LOCAL REPOS
# Local _ packages   :   /etc/QuickBox/packages
# Author             :   QuickBox.IO | JMSolo
# URL                :   https://quickbox.io
#
# QuickBox Copyright (C) 2017 QuickBox.io
# Licensed under GNU General Public License v3.0 GPL-3 (in short)
#
MASTER=$(cut -d: -f1 < /root/.master.info)
BTSYNCIP=$(ip route get 1 | sed -n 's/^.*src \([0-9.]*\) .*$/\1/p')

function _installBTSync1() {
    echo_progress_start "Installing btsync package"
    pacman -S --noconfirm resilio-sync
    echo_progress_done "Package installed"
}

function _installBTSync3() {
    mkdir -p /home/"${MASTER}"/.config/resilio-sync/storage/
}

function _installBTSync4() {
    mkdir /home/"${MASTER}"/sync_folder
    chown ${MASTER}: /home/${MASTER}/sync_folder
    chmod 2775 /home/${MASTER}/sync_folder
    chown ${MASTER}: -R /home/${MASTER}/.config/
}

function _installBTSync5() {
    cat > /etc/resilio-sync/config.json << RSCONF
{
    "listening_port" : 0,
    "storage_path" : "/home/${MASTER}/.config/resilio-sync/",
    "pid_file" : "/var/run/resilio-sync/sync.pid",

    "webui" :
    {
        "listen" : "${BTSYNCIP}:8888"
    }
}
RSCONF

    sed -i "s/=rslsync/=${MASTER}/g" /usr/lib/systemd/system/resilio-sync.service
    sed -i "s/rslsync:rslsync/${MASTER}:${MASTER}/g" /usr/lib/systemd/system/resilio-sync.service
    systemctl daemon-reload
}

function _installBTSync6() {
    touch /install/.btsync.lock
    systemctl enable -q resilio-sync 2>&1 | tee -a $log
    systemctl start resilio-sync >> $log 2>&1
    systemctl restart resilio-sync >> $log 2>&1
}

echo_progress_start "Installing btsync"
_installBTSync1
echo_progress_done "Installed"

echo_progress_start "Setting up btsync permissions"
_installBTSync3
_installBTSync4
echo_progress_done

echo_progress_start "Setting up btsync configurations"
_installBTSync5
echo_progress_done "Configured"

echo_progress_start "Starting btsync"
_installBTSync6
echo_progress_done "Started"

echo_success "BTSync installed"

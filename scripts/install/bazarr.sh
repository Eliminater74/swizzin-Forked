#!/bin/bash
# Bazarr installation
# Author: liara
# Copyright (C) 2019 Swizzin
# Licensed under GNU General Public License v3.0 GPL-3 (in short)
#
#   You may copy, distribute and modify the software as long as you track
#   changes/dates in source files. Any modifications to our software
#   including (via compiler) GPL-licensed code must also be made available
#   under the GPL along with build & install instructions.

_install() {

    user=$(cut -d: -f1 < /root/.master.info)
    . /etc/swizzin/sources/functions/pyenv
    systempy3_ver=$(get_candidate_version python3)

    if [[ $(python3 --version | awk '{print $2}') < "3.8.0" ]]; then
        PYENV=True
    fi

    case ${PYENV} in
        True)
            pyenv_install
            pyenv_install_version 3.11.3
            pyenv_create_venv 3.11.3 /opt/.venv/bazarr
            chown -R ${user}: /opt/.venv/bazarr
            ;;
        *)
            pacman -S --noconfirm python-pip python-venv
            python3_venv ${user} bazarr
            ;;
    esac

    if [[ $(_os_arch) =~ "arm" ]]; then
        pacman -S --noconfirm libxml2 libxslt python-libxml2 python-lxml unrar ffmpeg
    fi

    echo_progress_start "Downloading bazarr source"
    wget https://github.com/morpheus65535/bazarr/releases/latest/download/bazarr.zip -O /tmp/bazarr.zip >> $log 2>&1 || {
        echo_error "Failed to download"
        exit 1
    }
    echo_progress_done "Source downloaded"

    echo_progress_start "Extracting zip"
    rm -rf /opt/bazarr
    mkdir /opt/bazarr
    unzip /tmp/bazarr.zip -d /opt/bazarr >> $log 2>&1 || {
        echo_error "Failed to extract zip"
        exit 1
    }
    rm /tmp/bazarr.zip
    echo_progress_done "Zip extracted"

    chown -R "${user}": /opt/bazarr

    echo_progress_start "Installing python dependencies"
    sudo -u "${user}" bash -c "/opt/.venv/bazarr/bin/pip3 install -r /opt/bazarr/requirements.txt" >> $log 2>&1 || {
        echo_error "Dependencies failed to install"
        exit 1
    }
    mkdir -p /opt/bazarr/data/config/
    echo_progress_done "Dependencies installed"
}

_config() {
    if [[ -f /install/.sonarr.lock ]]; then
        echo_progress_start "Configuring bazarr to work with sonarr"

        sonarrConfigFile=/home/${user}/.config/Sonarr/config.xml

        if [[ -f "${sonarrConfigFile}" ]]; then
            sonarrapi=$(grep -oP "ApiKey>\K[^<]+" "${sonarrConfigFile}")
            sonarrport=$(grep -oP "\<Port>\K[^<]+" "${sonarrConfigFile}")
            sonarrbase=$(grep -oP "UrlBase>\K[^<]+" "${sonarrConfigFile}")
            sonarr_config="true"
        else
            echo_warn "Sonarr configuration was not found in ${sonarrConfigFile}, configure api key, port and url base manually in bazarr"
            sonarr_config="false"
        fi

        cat >> /opt/bazarr/data/config/config.ini << SONC
[sonarr]
apikey = ${sonarrapi} 
full_update = Daily
ip = 127.0.0.1
only_monitored = False
base_url = /${sonarrbase}
ssl = False
port = ${sonarrport}
SONC

        echo_progress_done
    fi

    if [[ -f /install/.radarr.lock ]]; then
        echo_progress_start "Configuring bazarr to work with radarr"

        radarrConfigFile=/home/${user}/.config/Radarr/config.xml

        if [[ -f "${radarrConfigFile}" ]]; then
            radarrapi=$(grep -oP "ApiKey>\K[^<]+" "${radarrConfigFile}")
            radarrport=$(grep -oP "\<Port>\K[^<]+" "${radarrConfigFile}")
            radarrbase=$(grep -oP "UrlBase>\K[^<]+" "${radarrConfigFile}")
            radarr_config="true"
        else
            echo_warn "Radarr configuration was not found in ${radarrConfigFile}, configure api key, port and url base manually in bazarr"
            radarr_config="false"
        fi

        cat >> /opt/bazarr/data/config/config.ini << RADC
[radarr]
apikey = ${radarrapi}
full_update = Daily
ip = 127.0.0.1
only_monitored = False
base_url = /${radarrbase}
ssl = False
port = ${radarrport}
RADC
        echo_progress_done
    fi

    cat >> /opt/bazarr/data/config/config.ini << BAZC
[general]
ip = 0.0.0.0
base_url = /
BAZC

    if [[ -f /install/.sonarr.lock ]] && [[ "${sonarr_config}" == "true" ]]; then
        echo "use_sonarr = True" >> /opt/bazarr/data/config/config.ini
    else
        echo "use_sonarr = False" >> /opt/bazarr/data/config/config.ini
    fi

    if [[ -f /install/.radarr.lock ]] && [[ "${radarr_config}" == "true" ]]; then
        echo "use_radarr = True" >> /opt/bazarr/data/config/config.ini
    else
        echo "use_radarr = False" >> /opt/bazarr/data/config/config.ini

    fi
}

_nginx() {

    if [[ -f /install/.nginx.lock ]]; then
        echo_progress_start "Configuring nginx"
        sleep 10
        bash /usr/local/bin/swizzin/nginx/bazarr.sh
        systemctl reload nginx
        echo_progress_done "nginx configured"
        echo_warn "If the bazarr wizard comes up, ensure that baseurl is set to: /bazarr/"
    else
        echo_info "Bazarr will run on port 6767"
    fi
}

_systemd() {
    echo_progress_start "Creating and starting service"
    cat > /etc/systemd/system/bazarr.service << BAZ
[Unit]
Description=Bazarr for ${user}
After=syslog.target network.target

[Service]
WorkingDirectory=/opt/bazarr
User=${user}
Group=${user}
UMask=0002
Restart=on-failure
RestartSec=5
Type=simple
ExecStart=/opt/.venv/bazarr/bin/python3 /opt/bazarr/bazarr.py
WorkingDirectory=/opt/bazarr
KillSignal=SIGINT
TimeoutStopSec=20
SyslogIdentifier=bazarr.${user}

[Install]
WantedBy=multi-user.target
BAZ

    chown -R ${user}: /opt/bazarr

    systemctl enable -q --now bazarr 2>&1 | tee -a $log
    echo_progress_done "Service started"
}

_install
_config
_nginx
_systemd

touch /install/.bazarr.lock

echo_success "Bazarr installed"

#!/bin/bash

. /koolshare/scripts/base.sh
. /koolshare/scripts/jshn.sh
. /koolshare/scripts/uci.sh

CONFIG_FILE=/koolshare/etc/dnsmasq.d/kms.conf
start_kms(){
    $APP_ROOT/bin/vlmcsd
    echo "srv-host=_vlmcs._tcp.lan,`uname -n`.lan,1688,0,100" > $CONFIG_FILE
    /etc/init.d/dnsmasq restart
}

stop_kms(){
    killall vlmcsd
    rm $CONFIG_FILE
    /etc/init.d/dnsmasq restart
}

open_port(){
    ifopen=`iptables -S -t filter | grep INPUT | grep dport |grep 1688`
    [ -z "$ifopen" ] && iptables -t filter -I INPUT -p tcp --dport 1688 -j ACCEPT > /dev/null 2>&1
}

close_port(){
    iptables -t filter -D INPUT -p tcp --dport 1688 -j ACCEPT > /dev/null 2>&1
}

write_firewall_start(){
        uci -q batch <<-EOT
delete firewall.ks_kms
set firewall.ks_kms=include
set firewall.ks_kms.type=script
set firewall.ks_kms.path=/koolshare/scripts/kms-config.sh
set firewall.ks_kms.family=any
set firewall.ks_kms.reload=1
commit firewall
EOT

}

remove_firewall_start(){
    uci -q batch <<-EOT
delete firewall.ks_kms
commit firewall
EOT

}

on_get() {
    local kms_enabled
    local kms_firewall
    config_load kms
    config_get kms_enabled main enabled
    config_get kms_firewall main firewall

    status=`pidof vlmcsd`

    echo '{"status":"'${status}'","enabled":"'$kms_enabled'","firewall":"'$kms_firewall'"}'
}

on_post() {
    local kms_enabled
    local kms_firewall

    json_load "$INPUT_JSON"
    json_get_var kms_enabled "enabled"
    json_get_var kms_firewall "firewall"
    uci -q batch <<-EOT
set kms.main.enabled=$kms_enabled
set kms.main.firewall=$kms_firewall
EOT

    if [ "$kms_enabled"x = "1"x ]; then
        killall vlmcsd

        if [ "$kms_firewall" == "1" ];then
            open_port
            write_firewall_start
        fi

        start_kms
        uci commit
        on_get
    elif [ "$kms_enabled"x = "0"x ]; then
        stop_kms
        close_port
        remove_firewall_start
        uci commit
        on_get
    else
        echo '{"status": "json_parse_failed"}'
    fi
}

on_start() {
    local kms_enabled
    local kms_firewall
    config_load kms
    config_get kms_enabled main enabled
    config_get kms_firewall main firewall
    if [ "$kms_enabled"x = "1"x ]; then
        killall vlmcsd
        if [ "$kms_firewall" == "1" ];then
            open_port
            write_firewall_start
        fi
        start_kms
    fi
}

on_stop() {
    stop_kms
    close_port
    remove_firewall_start
}

case $ACTION in
start)
    on_start
    ;;
post)
    on_post
    ;;
get)
    on_get
    ;;
installed)
    app_init_cfg '{"kms":[{"_id":"main","enabled":"0","firewall":"0"}]}'
    ;;
status)
    on_get
    ;;
stop)
    on_stop
    ;;
*)
    on_start
    ;;
esac


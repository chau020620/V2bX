#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}Lỗi: ${plain} Yêu cầu quyền truy cập root！\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "armbian"; then
    release="armbian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat|rocky|alma|oracle linux"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "armbian"; then
    release="armbian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat|rocky|alma|oracle linux"; then
    release="centos"
else
    echo -e "${red}Phiên bản hệ thống hiện tại không hỗ trợ！${plain}\n" && exit 1
fi

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}Yêu cầu CentOS 7 trở lên！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}Yêu cầu Ubuntu 16 trở lên！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}Yêu cầu Debian 8 trở lên！${plain}\n" && exit 1
    fi
fi

confirm() {
    if [[ $# > 1 ]]; then
        echo && read -rp "$1 [Mặc định $2]: " temp
        if [[ x"${temp}" == x"" ]]; then
            temp=$2
        fi
    else
        read -rp "$1 [y/n]: " temp
    fi
    if [[ x"${temp}" == x"y" || x"${temp}" == x"Y" ]]; then
        return 0
    else
        return 1
    fi
}

confirm_restart() {
    confirm "Cần khởi động lại V2bX" "y"
    if [[ $? == 0 ]]; then
        restart
    else
        show_menu
    fi
}

before_show_menu() {
    echo && echo -n -e "${yellow}Enter để quay lại: ${plain}" && read temp
    show_menu
}

install() {
    bash <(curl -Ls https://raw.githubusercontents.com/InazumaV/V2bX-script/master/install.sh)
    if [[ $? == 0 ]]; then
        if [[ $# == 0 ]]; then
            start
        else
            start 0
        fi
    fi
}

update() {
    if [[ $# == 0 ]]; then
        echo && echo -n -e "Nhập phiên bản(mặc định cài phiên bản mới nhất): " && read version
    else
        version=$2
    fi
    bash <(curl -Ls https://raw.githubusercontents.com/InazumaV/V2bX-script/master/install.sh) $version
    if [[ $? == 0 ]]; then
        echo -e "${green}Cập nhật hoàn tất, V2bX đang chạy${plain}"
        exit
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

config() {
    echo "V2bX sẽ tự khởi động lại sau khi thay đổi cấu hình"
    vi /etc/V2bX/config.yml
    sleep 2
    check_status
    case $? in
        0)
            echo -e "V2bX: ${green}Đang chạy${plain}"
            ;;
        1)
            echo -e "Đã phát hiện thấy V2bX không chạy, bạn có muốn xem nhật ký không？[Y/n]" && echo
            read -e -rp "(Mặc định: y):" yn
            [[ -z ${yn} ]] && yn="y"
            if [[ ${yn} == [Yy] ]]; then
               show_log
            fi
            ;;
        2)
            echo -e "V2bX: ${red}Chưa được cài đặt${plain}"
    esac
}

uninstall() {
    confirm "Bạn chắc muốn gỡ V2bX?" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    systemctl stop V2bX
    systemctl disable V2bX
    rm /etc/systemd/system/V2bX.service -f
    systemctl daemon-reload
    systemctl reset-failed
    rm /etc/V2bX/ -rf
    rm /usr/local/V2bX/ -rf

    echo ""
    echo -e "Đã gỡ cài đặt thành công, chạy lệnh ${green}rm /usr/bin/V2bX -f${plain} Để dọn dẹp"
    echo ""

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

start() {
    check_status
    if [[ $? == 0 ]]; then
        echo ""
        echo -e "${green}V2bX đang chạy, không cần khởi động lại${plain}"
    else
        systemctl start V2bX
        sleep 2
        check_status
        if [[ $? == 0 ]]; then
            echo -e "${green}V2bX khởi động thành công，sử dụng V2bX log để xem nhật ký${plain}"
        else
            echo -e "${red}V2bX không khởi động được, sử dụng V2bX log để xem nhật ký${plain}"
        fi
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

stop() {
    systemctl stop V2bX
    sleep 2
    check_status
    if [[ $? == 1 ]]; then
        echo -e "${green}V2bX Đã dừng${plain}"
    else
        echo -e "${red}V2bX không dừng được${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

restart() {
    systemctl restart V2bX
    sleep 2
    check_status
    if [[ $? == 0 ]]; then
        echo -e "${green}V2bX đã khởi động lại，sử dụng V2bX log để xem nhật ký${plain}"
    else
        echo -e "${red}V2bX không khởi động lại được, sử dụng V2bX log để xem nhật ký${plain}"
    fi
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

status() {
    systemctl status V2bX --no-pager -l
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

enable() {
    systemctl enable V2bX
    if [[ $? == 0 ]]; then
        echo -e "${green}V2bX tự khởi động${plain}"
    else
        echo -e "${red}V2bX không tự khởi động${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

disable() {
    systemctl disable V2bX
    if [[ $? == 0 ]]; then
        echo -e "${green}V2bX Đã hủy tự khởi động${plain}"
    else
        echo -e "${red}V2bX Không thể hủy tự khởi động${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

show_log() {
    journalctl -u V2bX.service -e --no-pager -f
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

install_bbr() {
    bash <(curl -L -s https://github.com/ylx2016/Linux-NetSpeed/raw/master/tcpx.sh)
}

update_shell() {
    wget -O /usr/bin/V2bX -N --no-check-certificate https://raw.githubusercontent.com/InazumaV/V2bX-script/master/V2bX.sh
    if [[ $? != 0 ]]; then
        echo ""
        echo -e "${red}Không thể tải tệp, kiểm tra kết nối đến Github Github${plain}"
        before_show_menu
    else
        chmod +x /usr/bin/V2bX
        echo -e "${green}Nâng cấp tệp lệnh thành công${plain}" && exit 0
    fi
}

# 0: running, 1: not running, 2: not installed
check_status() {
    if [[ ! -f /etc/systemd/system/V2bX.service ]]; then
        return 2
    fi
    temp=$(systemctl status V2bX | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return 0
    else
        return 1
    fi
}

check_enabled() {
    temp=$(systemctl is-enabled V2bX)
    if [[ x"${temp}" == x"enabled" ]]; then
        return 0
    else
        return 1;
    fi
}

check_uninstall() {
    check_status
    if [[ $? != 2 ]]; then
        echo ""
        echo -e "${red}V2bX đã cài đặt, không cần cài đặt lại${plain}"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

check_install() {
    check_status
    if [[ $? == 2 ]]; then
        echo ""
        echo -e "${red}Cần cài đặt V2bX${plain}"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

show_status() {
    check_status
    case $? in
        0)
            echo -e "V2bX: ${green}đang chạy${plain}"
            show_enable_status
            ;;
        1)
            echo -e "V2bX: ${yellow}không chạy${plain}"
            show_enable_status
            ;;
        2)
            echo -e "V2bX: ${red}chưa được cài đặt${plain}"
    esac
}

show_enable_status() {
    check_enabled
    if [[ $? == 0 ]]; then
        echo -e "Tự khởi động: ${green}Mở${plain}"
    else
        echo -e "Tự khởi động: ${red}Đóng${plain}"
    fi
}

generate_x25519_key() {
    echo -n "Đang tạo khóa x25519 Key："
    /usr/local/V2bX/V2bX x25519
    echo ""
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

show_V2bX_version() {
    echo -n "V2bX phiên bản："
    /usr/local/V2bX/V2bX version
    echo ""
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

add_node_config() {
    echo -e "${green}Chọn loại node：${plain}"
    echo -e "${green}1. xray${plain}"
    echo -e "${green}2. singbox${plain}"
    read -rp "Nhập：" core_type
    if [ "$core_type" == "1" ]; then
        core="xray"
        core_xray=true
    elif [ "$core_type" == "2" ]; then
        core="sing"
        core_sing=true
    else
        echo "Không hợp lệ, chọn 1: sing, 2: xray"
        continue
    fi
    while true; do
        read -rp "Nhập Node ID：" NodeID
        # 判断NodeID是否为正整数
        if [[ "$NodeID" =~ ^[0-9]+$ ]]; then
            break  # 输入正确，退出循环
        else
            echo "Lỗi, vui lòng nhập lại Node ID。"
        fi
    done
    
    echo -e "${yellow}Chọn giao thức：${plain}"
    echo -e "${green}1. Shadowsocks${plain}"
    echo -e "${green}2. Vless${plain}"
    echo -e "${green}3. Vmess${plain}"
    echo -e "${green}4. Hysteria${plain}"
    echo -e "${green}5. Hysteria2${plain}"
    echo -e "${green}6. Tuic${plain}"
    echo -e "${green}7. Trojan${plain}"
    read -rp "Nhập：" NodeType
    case "$NodeType" in
        1 ) NodeType="shadowsocks" ;;
        2 ) NodeType="vless" ;;
        3 ) NodeType="vmess" ;;
        4 ) NodeType="hysteria" ;;
        5 ) NodeType="hysteria2" ;;
        6 ) NodeType="tuic" ;;
        7 ) NodeType="trojan" ;;
        * ) NodeType="shadowsocks" ;;
    esac

    nodes_config+=(
        {
            \"Core\": \"$core\",
            \"ApiHost\": \"$ApiHost\",
            \"ApiKey\": \"$ApiKey\",
            \"NodeID\": $NodeID,
            \"NodeType\": \"$NodeType\",
            \"Timeout\": 4,
            \"ListenIP\": \"0.0.0.0\",
            \"SendIP\": \"0.0.0.0\",
            \"EnableProxyProtocol\": false,
            \"EnableUot\": true,
            \"EnableTFO\": true,
            \"DNSType\": \"UseIPv4\"
        }
    )
    nodes_config+=(",")
}
    

generate_config_file() {
    echo -e "${yellow}V2bX hướng dẫn thiết lập cấu hình${plain}"
    echo -e "${red}Đọc các ghi chú sau：${plain}"
    echo -e "${red}1. Chức năng này đang thử nghiệm${plain}"
    echo -e "${red}2. Tệp cấu hình được lưu vào /etc/V2bX/config.json${plain}"
    echo -e "${red}3. Tệp cấu hình gốc được lưu vào /etc/V2bX/config.json.bak${plain}"
    echo -e "${red}4. Không hỗ trợ TLS${plain}"
    echo -e "${red}5. Thiết lập này sẽ được kiểm tra riêng, bạn có muốn tiếp tục không？(y/n)${plain}"
    read -rp "Nhập：" continue_prompt
    if [[ "$continue_prompt" =~ ^[Nn][Oo]? ]]; then
        exit 0
    fi
    
    nodes_config=()
    first_node=true
    core_xray=false
    core_sing=false
    fixed_api_info=false
    check_api=false
    
    while true; do
        if [ "$first_node" = true ]; then
            read -rp "Nhập API website：" ApiHost
            read -rp "Nhập API key：" ApiKey
            read -rp "Bạn có muốn đặt API cố định？(y/n)" fixed_api
            if [ "$fixed_api" = "y" ] || [ "$fixed_api" = "Y" ]; then
                fixed_api_info=true
                echo -e "${red}Đã sửa thành công${plain}"
            fi
            first_node=false
            add_node_config
        else
            read -rp "Có tiếp tục thiết lập node không" continue_adding_node
            if [[ "$continue_adding_node" =~ ^[Nn][Oo]? ]]; then
                break
            elif [ "$fixed_api_info" = false ]; then
                read -rp "Nhập API website：" ApiHost
                read -rp "Nhập API key：" ApiKey
            fi
            add_node_config
        fi
    done

    # 根据核心类型生成 Cores
    if [ "$core_xray" = true ] && [ "$core_sing" = true ]; then
        cores_config="[
        {
            \"Type\": \"xray\",
            \"Log\": {
                \"Level\": \"error\",
                \"ErrorPath\": \"/etc/V2bX/error.log\"
            },
            \"OutboundConfigPath\": \"/etc/V2bX/custom_outbound.json\",
            \"RouteConfigPath\": \"/etc/V2bX/route.json\"
        },
        {
            \"Type\": \"sing\",
            \"Log\": {
                \"Level\": \"error\",
                \"Timestamp\": true
            },
            \"NTP\": {
                \"Enable\": true,
                \"Server\": \"time.apple.com\",
                \"ServerPort\": 0
            }
        }
        ]"
    elif [ "$core_xray" = true ]; then
        cores_config="[
        {
            \"Type\": \"xray\",
            \"Log\": {
                \"Level\": \"error\",
                \"ErrorPath\": \"/etc/V2bX/error.log\"
            },
            \"OutboundConfigPath\": \"/etc/V2bX/custom_outbound.json\",
            \"RouteConfigPath\": \"/etc/V2bX/route.json\"
        }
        ]"
    elif [ "$core_sing" = true ]; then
        cores_config="[
        {
            \"Type\": \"sing\",
            \"Log\": {
                \"Level\": \"error\",
                \"Timestamp\": true
            },
            \"NTP\": {
                \"Enable\": true,
                \"Server\": \"time.apple.com\",
                \"ServerPort\": 0
            }
        }
        ]"
    fi

    # 切换到配置文件目录
    cd /etc/V2bX
    
    # 备份旧的配置文件
    mv config.json config.json.bak
    formatted_nodes_config=$(echo "${nodes_config[*]}" | sed 's/,\s*$//')
    
    # 创建 config.json 文件
    cat <<EOF > /etc/V2bX/config.json
    {
        "Log": {
            "Level": "error",
            "Output": ""
        },
        "Cores": $cores_config,
        "Nodes": [$formatted_nodes_config]
    }
EOF
    
    # 创建 custom_outbound.json 文件
    cat <<EOF > /etc/V2bX/custom_outbound.json
    [
        {
            "tag": "IPv4_out",
            "protocol": "freedom",
            "settings": {
                "domainStrategy": "UseIPv4"
            }
        },
        {
            "tag": "IPv6_out",
            "protocol": "freedom",
            "settings": {
                "domainStrategy": "UseIPv6"
            }
        },
        {
            "tag": "direct",
            "protocol": "freedom"
        },
        {
            "protocol": "blackhole",
            "tag": "block"
        }
    ]
EOF
    
    # 创建 route.json 文件
    cat <<EOF > /etc/V2bX/route.json
    {
        "domainStrategy": "AsIs",
        "rules": [
            {
                "type": "field",
                "outboundTag": "block",
                "ip": [
                    "geoip:private",
                    "58.87.70.69"
                ]
            },
            {
                "type": "field",
                "outboundTag": "direct",
                "domain": [
                    "domain:zgovps.com"
                ]
            },
            {
                "type": "field",
                "outboundTag": "block",
                "domain": [
                    "regexp:(api|ps|sv|offnavi|newvector|ulog.imap|newloc)(.map|).(baidu|n.shifen).com",
                    "regexp:(.+.|^)(360|so).(cn|com)",
                    "regexp:(Subject|HELO|SMTP)",
                    "regexp:(torrent|.torrent|peer_id=|info_hash|get_peers|find_node|BitTorrent|announce_peer|announce.php?passkey=)",
                    "regexp:(^.@)(guerrillamail|guerrillamailblock|sharklasers|grr|pokemail|spam4|bccto|chacuo|027168).(info|biz|com|de|net|org|me|la)",
                    "regexp:(.?)(xunlei|sandai|Thunder|XLLiveUD)(.)",
                    "regexp:(..||)(dafahao|mingjinglive|botanwang|minghui|dongtaiwang|falunaz|epochtimes|ntdtv|falundafa|falungong|wujieliulan|zhengjian).(org|com|net)",
                    "regexp:(ed2k|.torrent|peer_id=|announce|info_hash|get_peers|find_node|BitTorrent|announce_peer|announce.php?passkey=|magnet:|xunlei|sandai|Thunder|XLLiveUD|bt_key)",
                    "regexp:(.+.|^)(360|speedtest|fast).(cn|com|net)",
                    "regexp:(.*.||)(guanjia.qq.com|qqpcmgr|QQPCMGR)",
                    "regexp:(.*.||)(rising|kingsoft|duba|xindubawukong|jinshanduba).(com|net|org)",
                    "regexp:(.*.||)(netvigator|torproject).(com|cn|net|org)",
                    "regexp:(..||)(visa|mycard|gov|gash|beanfun|bank).",
                    "regexp:(.*.||)(gov|12377|12315|talk.news.pts.org|creaders|zhuichaguoji|efcc.org|cyberpolice|aboluowang|tuidang|epochtimes|nytimes|zhengjian|110.qq|mingjingnews|inmediahk|xinsheng|breakgfw|chengmingmag|jinpianwang|qi-gong|mhradio|edoors|renminbao|soundofhope|xizang-zhiye|bannedbook|ntdtv|12321|secretchina|dajiyuan|boxun|chinadigitaltimes|dwnews|huaglad|oneplusnews|epochweekly|cn.rfi).(cn|com|org|net|club|net|fr|tw|hk|eu|info|me)",
                    "regexp:(.*.||)(miaozhen|cnzz|talkingdata|umeng).(cn|com)",
                    "regexp:(.*.||)(mycard).(com|tw)",
                    "regexp:(.*.||)(gash).(com|tw)",
                    "regexp:(.bank.)",
                    "regexp:(.*.||)(pincong).(rocks)",
                    "regexp:(.*.||)(taobao).(com)",
                    "regexp:(.*.||)(laomoe|jiyou|ssss|lolicp|vv1234|0z|4321q|868123|ksweb|mm126).(com|cloud|fun|cn|gs|xyz|cc)",
                    "regexp:(flows|miaoko).(pages).(dev)"
                ]
            },
            {
                "type": "field",
                "outboundTag": "block",
                "ip": [
                    "127.0.0.1/32",
                    "10.0.0.0/8",
                    "fc00::/7",
                    "fe80::/10",
                    "172.16.0.0/12"
                ]
            },
            {
                "type": "field",
                "outboundTag": "block",
                "protocol": [
                    "bittorrent"
                ]
            },
            {
                "type": "field",
                "outboundTag": "block",
                "port": "23,24,25,107,194,445,465,587,992,3389,6665-6669,6679,6697,6881-6999,7000"
            }
        ]
    }
EOF
                

    echo -e "${green}Tạo cấu hình thành công, đang khởi động lại v2bx${plain}"
    restart 0
    before_show_menu
}

# 放开防火墙端口
open_ports() {
    systemctl stop firewalld.service 2>/dev/null
    systemctl disable firewalld.service 2>/dev/null
    setenforce 0 2>/dev/null
    ufw disable 2>/dev/null
    iptables -P INPUT ACCEPT 2>/dev/null
    iptables -P FORWARD ACCEPT 2>/dev/null
    iptables -P OUTPUT ACCEPT 2>/dev/null
    iptables -t nat -F 2>/dev/null
    iptables -t mangle -F 2>/dev/null
    iptables -F 2>/dev/null
    iptables -X 2>/dev/null
    netfilter-persistent save 2>/dev/null
    echo -e "${green}Đã mở thành công tường lửa！${plain}"
}

show_usage() {
    echo "Lệnh sử dụng v2bx: "
    echo "------------------------------------------"
    echo "V2bX              - Mở bảng điều khiển V2bX"
    echo "V2bX start        - Chạy V2bX"
    echo "V2bX stop         - Dừng V2bX"
    echo "V2bX restart      - Khởi động lại V2bX"
    echo "V2bX status       - Trạng thái V2bX"
    echo "V2bX enable       - V2bX Tự động chạy"
    echo "V2bX disable      - V2bX Không tự động chạy"
    echo "V2bX log          - Nhật ký V2bX"
    echo "V2bX x25519       - Tạo khóa x25519"
    echo "V2bX generate     - Tạo cấu hình V2bX"
    echo "V2bX update       - Cập nhật V2bX"
    echo "V2bX update x.x.x - Cập nhật V2bX phiên bản x.x.x"
    echo "V2bX install      - Cài đặt V2bX"
    echo "V2bX uninstall    - Gỡ cài đặt V2bX"
    echo "V2bX version      - Phiên bản V2bX hiện tại"
    echo "------------------------------------------"
}

show_menu() {
    echo -e "
  ${green}Bảng điều khiển V2bX，${plain}${red}Không áp dụng docker${plain}
--- https://github.com/InazumaV/V2bX ---
  ${green}0.${plain} Sửa đổi cấu hình
————————————————
  ${green}1.${plain} Cài đặt V2bX
  ${green}2.${plain} Cập nhật V2bX
  ${green}3.${plain} Gỡ cài đặt V2bX
————————————————
  ${green}4.${plain} Bắt đầu V2bX
  ${green}5.${plain} Dừng V2bX
  ${green}6.${plain} Khởi động lại V2bX
  ${green}7.${plain} Trạng thái V2bX
  ${green}8.${plain} Nhật ký V2bX
————————————————
  ${green}9.${plain} Đặt V2bX tự khởi động
  ${green}10.${plain} Hủy V2bX tự khởi động
————————————————
  ${green}11.${plain} Cài đặt bbr
  ${green}12.${plain} Phiên bản V2bX
  ${green}13.${plain} Tạo khóa X25519
  ${green}14.${plain} Nâng cấp tập lệnh V2bX
  ${green}15.${plain} Tạo tệp cấu hình V2bX
  ${green}16.${plain} Mở tất cả cổng mạng VPS
 "
 #后续更新可加入上方字符串中
    show_status
    echo && read -rp "Nhập lựa chọn [0-16]: " num

    case "${num}" in
        0) config ;;
        1) check_uninstall && install ;;
        2) check_install && update ;;
        3) check_install && uninstall ;;
        4) check_install && start ;;
        5) check_install && stop ;;
        6) check_install && restart ;;
        7) check_install && status ;;
        8) check_install && show_log ;;
        9) check_install && enable ;;
        10) check_install && disable ;;
        11) install_bbr ;;
        12) check_install && show_V2bX_version ;;
        13) check_install && generate_x25519_key ;;
        14) update_shell ;;
        15) generate_config_file ;;
        16) open_ports ;;
        *) echo -e "${red}Vui lòng nhập lại [0-16]${plain}" ;;
    esac
}


if [[ $# > 0 ]]; then
    case $1 in
        "start") check_install 0 && start 0 ;;
        "stop") check_install 0 && stop 0 ;;
        "restart") check_install 0 && restart 0 ;;
        "status") check_install 0 && status 0 ;;
        "enable") check_install 0 && enable 0 ;;
        "disable") check_install 0 && disable 0 ;;
        "log") check_install 0 && show_log 0 ;;
        "update") check_install 0 && update 0 $2 ;;
        "config") config $* ;;
        "generate") generate_config_file ;;
        "install") check_uninstall 0 && install 0 ;;
        "uninstall") check_install 0 && uninstall 0 ;;
        "x25519") check_install 0 && generate_x25519_key 0 ;;
        "version") check_install 0 && show_V2bX_version 0 ;;
        "update_shell") update_shell ;;
        *) show_usage
    esac
else
    show_menu
fi

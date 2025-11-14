#!/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

RED_COLOR="\033[0;31m"
NO_COLOR="\033[0m"
GREEN="\033[32m\033[01m"
BLUE="\033[0;36m"
FUCHSIA="\033[0;35m"

echo -e "${BLUE}
----------------------------------特别声明----------------------------------
--本脚本采用 IPSEC TUNNEL的方式来加密流量数据，加密方式为AES-128-GCM--
----------本脚本只支持debian，在debian10/debian11/debian12上测试通过----------
-----------------------------write by tg:@ljfxz-----------------------------
"
network_name=`ifconfig | awk -F: '{print $1}'| sed -n "1,1p"`
mkdir -p /etc/ipt
network_ip=`ifconfig ${network_name} | grep 'inet ' | awk '{print $2}'`

iptables_install(){
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
sysctl -p
apt-get update && apt-get install -y iptables host net-tools
iptables -P INPUT ACCEPT
iptables -P OUTPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables-save > /etc/iptables.up.rules
iptables-restore < /etc/iptables.up.rules
cat > /etc/ipt/iptablesddns.sh << "EOF"
#!/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
domainlist_rows=`wc -l /etc/ipt/domainlist.txt | awk '{print $1}'`
for((i=1;i<=${domainlist_rows};i++));  
do
domain=`sed -n "$i, 1p" /etc/ipt/domainlist.txt | awk '{print $1}'`
domain_ip=`sed -n "$i, 1p" /etc/ipt/domainlist.txt | awk '{print $2}'`
domain_now_ip=`host ${domain} | grep "address" | tail -n +1 | awk '{print $4}'`
if [ "${domain_ip}" = "${domain_now_ip}" ]; then
exit 1
else
sed -i "s/${domain_ip}/${domain_now_ip}/g" `grep -rl "${domain_ip}" /etc/iptables.up.rules`
sed -i "s/${domain_ip}/${domain_now_ip}/g" `grep -rl "${domain_ip}" /etc/ipt/domainlist.txt`
fi
done
iptables-restore < /etc/iptables.up.rules
EOF
chmod +x /etc/ipt/iptablesddns.sh

cat > /usr/lib/systemd/system/iptablesddns.service << EOF
[Unit]
Description=iptablesddns

[Service]
Type=simple
ExecStart=/usr/bin/bash /etc/ipt/iptablesddns.sh
Restart=always
RestartSec=15

[Install]
WantedBy=multi-user.target
EOF
systemctl enable iptablesddns --now
systemctl daemon-reload
}

ipsec_tunnel_set1(){
cat > /etc/ipt/iptzq.sh << EOF
#!/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
EOF
read -p "输入对端ip:" REMOTE_IP
read -p "自定义本机虚拟ip:" LOCAL_VIRTUAL_IP
read -p "自定义对端虚拟ip:" REMOTE_VIRTUAL_IP
ip link add ljfxz1 type dummy
ip addr add ${LOCAL_VIRTUAL_IP} dev ljfxz1
ip link set dev ljfxz1 up mtu 1400
ip xfrm state add src ${network_ip} dst ${REMOTE_IP} proto esp spi 0x28f39549 reqid 0x28f39549 mode tunnel aead 'rfc4106(gcm(aes))' 0x492e8ffe718a95a00c1893ea61afc64997f4732848ccfe6ea07db483175cb18de9ae411a 128
ip xfrm state add src ${REMOTE_IP} dst ${network_ip} proto esp spi 0x622a73b4 reqid 0x622a73b4 mode tunnel aead 'rfc4106(gcm(aes))' 0x093bfee2212802d626716815f862da31bcc7d9c44cfe3ab8049e7604b2feb1254869d25b 128
ip xfrm policy add src ${LOCAL_VIRTUAL_IP} dst ${REMOTE_VIRTUAL_IP} dir out tmpl src ${network_ip} dst ${REMOTE_IP} proto esp reqid 0x28f39549 mode tunnel
ip xfrm policy add src ${REMOTE_VIRTUAL_IP} dst ${LOCAL_VIRTUAL_IP} dir in tmpl src ${REMOTE_IP} dst ${network_ip} proto esp reqid 0x622a73b4 mode tunnel
ip xfrm policy add src ${REMOTE_VIRTUAL_IP} dst ${LOCAL_VIRTUAL_IP} dir fwd tmpl src ${REMOTE_IP} dst ${network_ip} proto esp reqid 0x622a73b4 mode tunnel
ip route add ${REMOTE_VIRTUAL_IP} dev ljfxz1 src ${LOCAL_VIRTUAL_IP}
cat >> /etc/ipt/iptzq.sh << EOF
ip link add ljfxz1 type dummy
ip addr add ${LOCAL_VIRTUAL_IP} dev ljfxz1
ip link set dev ljfxz1 up mtu 1400
ip xfrm state add src ${network_ip} dst ${REMOTE_IP} proto esp spi 0x28f39549 reqid 0x28f39549 mode tunnel aead 'rfc4106(gcm(aes))' 0x492e8ffe718a95a00c1893ea61afc64997f4732848ccfe6ea07db483175cb18de9ae411a 128
ip xfrm state add src ${REMOTE_IP} dst ${network_ip} proto esp spi 0x622a73b4 reqid 0x622a73b4 mode tunnel aead 'rfc4106(gcm(aes))' 0x093bfee2212802d626716815f862da31bcc7d9c44cfe3ab8049e7604b2feb1254869d25b 128
ip xfrm policy add src ${LOCAL_VIRTUAL_IP} dst ${REMOTE_VIRTUAL_IP} dir out tmpl src ${network_ip} dst ${REMOTE_IP} proto esp reqid 0x28f39549 mode tunnel
ip xfrm policy add src ${REMOTE_VIRTUAL_IP} dst ${LOCAL_VIRTUAL_IP} dir in tmpl src ${REMOTE_IP} dst ${network_ip} proto esp reqid 0x622a73b4 mode tunnel
ip xfrm policy add src ${REMOTE_VIRTUAL_IP} dst ${LOCAL_VIRTUAL_IP} dir fwd tmpl src ${REMOTE_IP} dst ${network_ip} proto esp reqid 0x622a73b4 mode tunnel
ip route add ${REMOTE_VIRTUAL_IP} dev ljfxz1 src ${LOCAL_VIRTUAL_IP}
iptables-restore < /etc/iptables.up.rules
EOF
}

ipsec_tunnel_set2(){
cat > /etc/ipt/iptzq.sh << EOF
#!/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
EOF
read -p "输入对端ip:" REMOTE_IP
read -p "自定义本机虚拟ip:" LOCAL_VIRTUAL_IP
read -p "自定义对端虚拟ip:" REMOTE_VIRTUAL_IP
ip link add ljfxz1 type dummy
ip addr add ${LOCAL_VIRTUAL_IP} dev ljfxz1
ip link set dev ljfxz1 up mtu 1400
ip xfrm state add src ${REMOTE_IP} dst ${network_ip} proto esp spi 0x28f39549 reqid 0x28f39549 mode tunnel aead 'rfc4106(gcm(aes))' 0x492e8ffe718a95a00c1893ea61afc64997f4732848ccfe6ea07db483175cb18de9ae411a 128
ip xfrm state add src ${network_ip} dst ${REMOTE_IP} proto esp spi 0x622a73b4 reqid 0x622a73b4 mode tunnel aead 'rfc4106(gcm(aes))' 0x093bfee2212802d626716815f862da31bcc7d9c44cfe3ab8049e7604b2feb1254869d25b 128
ip xfrm policy add src ${LOCAL_VIRTUAL_IP} dst ${REMOTE_VIRTUAL_IP} dir out tmpl src ${network_ip} dst ${REMOTE_IP} proto esp reqid 0x622a73b4 mode tunnel 
ip xfrm policy add src ${REMOTE_VIRTUAL_IP} dst ${LOCAL_VIRTUAL_IP} dir in tmpl src ${REMOTE_IP} dst ${network_ip} proto esp reqid 0x28f39549 mode tunnel 
ip xfrm policy add src ${REMOTE_VIRTUAL_IP} dst ${LOCAL_VIRTUAL_IP} dir fwd tmpl src ${REMOTE_IP} dst ${network_ip} proto esp reqid 0x28f39549 mode tunnel
ip route add ${REMOTE_VIRTUAL_IP} dev ljfxz1 src ${LOCAL_VIRTUAL_IP} 
cat >> /etc/ipt/iptzq.sh << EOF
ip link add ljfxz1 type dummy
ip addr add ${LOCAL_VIRTUAL_IP} dev ljfxz1
ip link set dev ljfxz1 up mtu 1400
ip xfrm state add src ${REMOTE_IP} dst ${network_ip} proto esp spi 0x28f39549 reqid 0x28f39549 mode tunnel aead 'rfc4106(gcm(aes))' 0x492e8ffe718a95a00c1893ea61afc64997f4732848ccfe6ea07db483175cb18de9ae411a 128
ip xfrm state add src ${network_ip} dst ${REMOTE_IP} proto esp spi 0x622a73b4 reqid 0x622a73b4 mode tunnel aead 'rfc4106(gcm(aes))' 0x093bfee2212802d626716815f862da31bcc7d9c44cfe3ab8049e7604b2feb1254869d25b 128
ip xfrm policy add src ${LOCAL_VIRTUAL_IP} dst ${REMOTE_VIRTUAL_IP} dir out tmpl src ${network_ip} dst ${REMOTE_IP} proto esp reqid 0x622a73b4 mode tunnel 
ip xfrm policy add src ${REMOTE_VIRTUAL_IP} dst ${LOCAL_VIRTUAL_IP} dir in tmpl src ${REMOTE_IP} dst ${network_ip} proto esp reqid 0x28f39549 mode tunnel 
ip xfrm policy add src ${REMOTE_VIRTUAL_IP} dst ${LOCAL_VIRTUAL_IP} dir fwd tmpl src ${REMOTE_IP} dst ${network_ip} proto esp reqid 0x28f39549 mode tunnel
ip route add ${REMOTE_VIRTUAL_IP} dev ljfxz1 src ${LOCAL_VIRTUAL_IP} 
iptables-restore < /etc/iptables.up.rules
EOF
}

iptables_set1(){
iptables -t nat -F
iptables -t nat -X
iptables -t nat -Z
iptables-save > /etc/iptables.up.rules
iptables-restore < /etc/iptables.up.rules
virtual_ip=`ifconfig ljfxz1 | grep 'inet ' | awk '{print $2}'`
read -p "输入要监听的ip:" LISTEN_IP
read -p "输入要监听的端口段:" LISTEN_PORT
read -p "输入对端虚拟ip:" REMOTE_VIRTUAL_IP
read -p "输入要转发的端口段:" REMOTE_PORT
iptables -t nat -A PREROUTING -d ${LISTEN_IP} -p tcp -m tcp --dport ${LISTEN_PORT} -j DNAT --to-destination ${REMOTE_VIRTUAL_IP}
iptables -t nat -A PREROUTING -d ${LISTEN_IP} -p udp -m udp --dport ${LISTEN_PORT} -j DNAT --to-destination ${REMOTE_VIRTUAL_IP}
iptables -t nat -A POSTROUTING -d ${REMOTE_VIRTUAL_IP} -p tcp -m tcp --dport ${REMOTE_PORT} -j SNAT --to-source ${virtual_ip}
iptables -t nat -A POSTROUTING -d ${REMOTE_VIRTUAL_IP} -p udp -m udp --dport ${REMOTE_PORT} -j SNAT --to-source ${virtual_ip}
iptables-save > /etc/iptables.up.rules
iptables-restore < /etc/iptables.up.rules
read -e -p "是否继续 添加端口转发配置？[Y/n]:" addyn
[[ -z ${addyn} ]] && addyn="y"
if [[ ${addyn} == [Yy] ]]; then
iptables_set1
else
ipt_menu
fi
}

iptables_set2(){
iptables -t nat -F
iptables -t nat -X
iptables -t nat -Z
iptables-save > /etc/iptables.up.rules
iptables-restore < /etc/iptables.up.rules
iptlist_rows=`wc -l /etc/ipt/iptlist.txt | awk '{print $1}'`
for((i=1;i<=$iptlist_rows;i++));  
do
virtual_ip=`sed -n "$i, 1p" /etc/ipt/iptlist.txt | awk '{print $1}'` 
LISTEN_PORT=`sed -n "$i, 1p" /etc/ipt/iptlist.txt | awk '{print $2}'`
REMOTE_IP=`sed -n "$i, 1p" /etc/ipt/iptlist.txt | awk '{print $3}'`
REMOTE_PORT=`sed -n "$i, 1p" /etc/ipt/iptlist.txt | awk '{print $4}'`
network_ip=`sed -n "$i, 1p" /etc/ipt/iptlist.txt | awk '{print $5}'`
ip_regex='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
if [[ ${REMOTE_IP} =~ ${ip_regex} ]]; then
iptables -t nat -A PREROUTING -d ${virtual_ip} -p tcp -m tcp --dport ${LISTEN_PORT} -j DNAT --to-destination ${REMOTE_IP}:${REMOTE_PORT}
iptables -t nat -A PREROUTING -d ${virtual_ip} -p udp -m udp --dport ${LISTEN_PORT} -j DNAT --to-destination ${REMOTE_IP}:${REMOTE_PORT}
iptables -t nat -A POSTROUTING -d ${REMOTE_IP} -p tcp -m tcp --dport ${REMOTE_PORT} -j SNAT --to-source ${network_ip}
iptables -t nat -A POSTROUTING -d ${REMOTE_IP} -p udp -m udp --dport ${REMOTE_PORT} -j SNAT --to-source ${network_ip}
else
domainip=`host ${REMOTE_IP} | grep "address" | tail -n +1 | awk '{print $4}'`
iptables -t nat -A PREROUTING -d ${virtual_ip} -p tcp -m tcp --dport ${LISTEN_PORT} -j DNAT --to-destination ${domainip}:${REMOTE_PORT}
iptables -t nat -A PREROUTING -d ${virtual_ip} -p udp -m udp --dport ${LISTEN_PORT} -j DNAT --to-destination ${domainip}:${REMOTE_PORT}
iptables -t nat -A POSTROUTING -d ${domainip} -p tcp -m tcp --dport ${REMOTE_PORT} -j SNAT --to-source ${network_ip}
iptables -t nat -A POSTROUTING -d ${domainip} -p udp -m udp --dport ${REMOTE_PORT} -j SNAT --to-source ${network_ip}
echo "${REMOTE_IP} ${domainip}" >> /etc/ipt/domainlist.txt
fi
done
iptables-save > /etc/iptables.up.rules
iptables-restore < /etc/iptables.up.rules
read -e -p "是否继续 添加端口转发配置？[Y/n]:" addyn
[[ -z ${addyn} ]] && addyn="y"
if [[ ${addyn} == [Yy] ]]; then
iptables_set2
else
ipt_menu
fi
}

view_iptables_list(){
iptables_list_rows=$(iptables -t nat -nL PREROUTING --line-number | tail -n +3 | wc -l)
for((i=1;i<=$iptables_list_rows;i++));
do
num=`iptables -t nat -nL PREROUTING --line-number | grep "$i    DNAT" | awk '{print $1}'`
type=`iptables -t nat -nL PREROUTING --line-number | grep "$i    DNAT" | awk '{print $7}'`
listen_ip=`iptables -t nat -nL PREROUTING --line-number | grep "$i    DNAT" | awk '{print $6}'`
listen_port=`iptables -t nat -nL PREROUTING --line-number | grep "$i    DNAT" | awk '{print $8}' | awk -F "dpt:" '{print $2}'`
remote_ipandport=`iptables -t nat -nL PREROUTING --line-number | grep "$i    DNAT" | awk '{print $9}' | awk -F "to:" '{print $2}'`
echo "序号:${num}   类型:${type}   监听>${listen_ip}:${listen_port}   转发>${remote_ipandport}"
done
}

delete_iptables(){
view_iptables_list
read -p "输入要删除的序号:" Num
iptables -t nat -D PREROUTING ${Num}
iptables -t nat -D POSTROUTING ${Num}
read -e -p "是否继续 删除转发配置？[Y/n]:" addyn
[[ -z ${addyn} ]] && addyn="y"
if [[ ${addyn} == [Yy] ]]; then
delete_iptables
else
ipt_menu
fi
iptables-save > /etc/iptables.up.rules
iptables-restore < /etc/iptables.up.rules
}

add_ipsec_tunnel(){
echo -e "
 ${GREEN} 1.中转机(入口)
 ${GREEN} 2.对端机(出口)
 "
read -p "输入序号:" aNum
if [ "${aNum}" = "1" ];then
ipsec_tunnel_set1
elif [ "${aNum}" = "2" ];then
ipsec_tunnel_set2
fi
chmod +x /etc/ipt/iptzq.sh
cat > /usr/lib/systemd/system/iptzq.service << EOF
[Unit]
Description=iptzq server

[Service]
Type=simple
ExecStart=/usr/bin/bash /etc/ipt/iptzq.sh

[Install]
WantedBy=multi-user.target
EOF
systemctl enable iptzq --now
systemctl daemon-reload
ipt_menu
}

add_iptables(){
echo -e "
 ${GREEN} 1.中转机(入口)
 ${GREEN} 2.对端机(出口)
 "
read -p "输入序号:" aNum
if [ "${aNum}" = "1" ];then
iptables_set1
elif [ "${aNum}" = "2" ];then
iptables_set2
fi
}

ipt_menu(){
echo -e "
 ${GREEN} 1.配置ipsec tunnel
 ${GREEN} 2.安装iptables
 ${GREEN} 3.添加转发规则
 ${GREEN} 4.删除转发规则
 ${GREEN} 5.查看转发规则
 ${GREEN} 0.退出脚本
 "
read -p " 请输入数字后[0-5] 按回车键:" num
case "$num" in
	1)
        add_ipsec_tunnel
	;;
	2)
	iptables_install
	;;
	3)
	add_iptables
	;;
	4)
	delete_iptables
	;;
        5)
	view_iptables_list
	;;
	0)
	exit 1
	;;
	*)	
	echo "请输入正确数字 [0-5] 按回车键"
	ipt_menu
	;;
esac
}
ipt_menu

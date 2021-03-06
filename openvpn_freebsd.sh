#!/bin/sh
#      usage: /bin/sh openvpn_freebsd.sh [-i <ip>] [-p <port>] [-u user1,user2...] [-d] [-t]
#            -i IP where to listen (default last)
#            -p port on which listen(default 1194)
#            -u a list of users separated by commas(default client)
#            -c duplicate cn(defaul off)
#	     -t use tcp(default udp)
#            -d (do not rebuild server keys and configs may be used to recreate or create new client keys )" 
export PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/games:/usr/local/sbin:/usr/local/bin

export red="\e[0;31m"
export NC="\e[0m"
export blue="\e[0;34m"
export green="\e[0;32m"
export check_pkgng="`whereis pkg|grep man`"
export check_pkgold="/usr/sbin/pkg_info"
export OVPN="/usr/local/etc/openvpn/"
export main_dir="/usr/local/etc/openvpn/easy-rsa"
export last_ip=`netstat -bind | grep -vE "^lo|^tap|^tun"|sed -nE 's/([a-z0-9]+) +([0-9]+|-) +[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\/?[0-9]* +([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}) +[0-9]+ +.*$/\3/p'|grep -vE "^(10|192\.168|172|169|127)\."|tail -n 1`
export eth_name=`netstat -bind |grep $last_ip| sed -nE 's/([a-z0-9]+) +([0-9]+|-) +[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\/?[0-9]* +([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}) +[0-9]+ +.*$/\1/p'`
export port=1194
export users=client
export build_ch=0
export duplicate="#"
export protocol="udp"
export protocol_client="udp"
export comment=""
export internal_ip="192.168.20"
while getopts "i:p:u:dct" opt; do
  case $opt in
    i)
      export last_ip=$OPTARG
      export eth_name=`netstat -bind | grep $last_ip| sed -nE 's/([a-z0-9]+) +([0-9]+|-) +[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\/?[0-9]* +([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}) +[0-9]+ +.*$/\1/p'`
     ;;
    p)
     export port=$OPTARG
     ;;
    u)
     export users=$OPTARG
     ;;
    d)
     export build_ch=1
     ;;
    c)
      export duplicate=""
     ;;
    t)
      export protocol="tcp-server"
      export protocol_client="tcp-client"
      export comment="#"
      ;;
    *)
      echo "usage: $0 [-i <ip>] [-p <port>] [-u user1,user2...] [-d] [-t]
	    -i IP where to listen (default last)
	    -p port on which listen(default 1194)
	    -u a list of users separated by commas(default client)
	    -c duplicate cn(defaul off)
 	    -t use tcp(default udp)
	    -d (do not rebuild server keys and configs may be used to recreate or create new client keys )" 
	exit 0
      ;;
  esac
done
if [ "$check_pkgng" != "" ]
then
 export pkgng_ch="`pkg info|grep openvpn`"
else
 export pkgng_ch=""
fi
if [ -f $check_pkgold ]
then
 export pkg_ch="`pkg_info|grep openvpn`"
else 
 export pkg_ch=""
fi


if [ "$check_pkgng" != "" ]
then
 export pkgng_ch2="`pkg info|grep easy-rsa`"
else
 export pkgng_ch2=""
fi

if which pkg_info 2>/dev/null
then
 export pkg_ch2="`pkg_info|grep easy-rsa`"
else
 export pkg_ch2=""
fi

if  [ "$pkg_ch2" != "" ] || [ "$pkgng_ch2" != "" ]
 then echo -e "${blue}easy-rsa is present${NC}"
else
  echo -e "${blue}Installing easy-rsa${NC}"
  if [ -d "/usr/ports/security/easy-rsa2" ];then
   cd  /usr/ports/security/easy-rsa2;make install clean BATCH=yes >> /dev/null
  else
  cd /usr/ports/security/easy-rsa
  make install clean BATCH=yes >> /dev/null 
  fi
    if [ $? -ne 0 ];then
   echo -e "${red}Can't install easy-rsa from ports${NC}"
   exit 1
  fi

fi

if  [ "$pkg_ch" != "" ] || [ "$pkgng_ch" != "" ]
 then echo -e "${blue}openvpn is present${NC}"
else
  echo -e "${blue}Installing openvpn. May take some time${NC}"
  cd /usr/ports/security/openvpn
  make install clean BATCH=yes >> /dev/null
  if [ $? -ne 0 ];then 
   echo -e "${red}Can't install openvpn from ports${NC}"
   exit 1
  fi
fi 


mkdir -p $main_dir
if [ -d "/usr/local/share/doc/openvpn/easy-rsa" ];then
  cp -rp /usr/local/share/doc/openvpn/easy-rsa/1.0/*  $main_dir
 export buildserverkey="build-key server"
elif [ -d "/usr/local/share/easy-rsa" ];then
   cp -rp /usr/local/share/easy-rsa/* $main_dir
  export buildserverkey="build-key-server server"
else
  echo -e "${red}I don't know where is easy-rsa${NC}"
  exit 1
fi

cd $main_dir
ls |grep build|while read NAME
do cat $NAME | sed 's/\(.*\)--interact\(.*\)/\1\2/p' >> $NAME\_
 mv $NAME\_ $NAME
done
chmod +x build*

if [ $build_ch = "0" ];then
echo -e "${blue}Loading required modules and creating configs for soft${NC}"

if kldstat|grep -q if_tap; then echo -e "${blue}if_tap allready loaded${NC}";else kldload if_tap.ko;fi
if kldstat|grep -q ipl; then echo -e "${blue}ipl allready loaded${NC}"
 elif [ -f /boot/kernel/ipl.ko ]; then 
   kldload ipl.ko
 elif [ !-f /boot/kernel/ipl.ko ];then 
   cd /usr/src/sys/modules/ipfilter;make >>/dev/null;cp ipl.ko /boot/kernel/ipl.ko;kldload ipl
   cd $main_dir
 fi
	sysctl net.inet.ip.forwarding=1
	if grep -q "^openvpn_enable" /etc/rc.conf ; then  echo -e "${blue}allredy openvpn_enable${NC}";else  echo "openvpn_enable=YES" >> /etc/rc.conf ; fi
	if grep -q "^openvpn_if" /etc/rc.conf ; then  echo -e "${blue}allredy openvpn_if${NC}";else echo "openvpn_if=tap" >> /etc/rc.conf ; fi
	if grep -q "^gateway_enable" /etc/rc.conf ; then echo -e "${blue}allredy gateway_enable${NC}";else   echo "gateway_enable=YES" >> /etc/rc.conf ; fi
	if grep -q "^ipnat_enable" /etc/rc.conf ; then echo -e "${blue}allredy ipnat_enable${NC}";else  echo "ipnat_enable=YES" >> /etc/rc.conf ; fi
	if grep -q "^openvpn_configfile" /etc/rc.conf ; then echo -e "${blue}allready configfile set${NC}";else echo "openvpn_configfile=\"/usr/local/etc/openvpn/server.conf\"" >> /etc/rc.conf ;fi 
	touch /etc/ipnat.rules
	if grep -q "map $eth_name ${internal_ip}.1/24 -> $last_ip/32" /etc/ipnat.rules ; then echo -e "${blue}ipnat rules allready exist${NC}"
          elif grep -q "${internal_ip}.1/24" /etc/ipnat.rules
             then
                echo -e "${blue}There is rules for ${internal_ip}.1 in ipnat.rules, generating another network...${NC}"
 		export octet="`echo ${internal_ip}|sed -nE 's/192\.168\.([0-9]+)/\1/p'`"
		export test=1
		while [ $test -eq 1 ];do
	         export octet=$((octet+1))
		 export internal_ip="192.168.$octet"
		  if grep -q "map $eth_name ${internal_ip}.1/24 -> $last_ip/32" /etc/ipnat.rules ; then echo -e "${blue}ipnat rules created${NC}";export test=2
		  elif grep -q "${internal_ip}.1/24" /etc/ipnat.rules
		   then
		    export test=1
		   else
		   export test=2
		   echo "map $eth_name ${internal_ip}.1/24 -> $last_ip/32 "   >> /etc/ipnat.rules
 		   echo -e "${blue}ipnat rules created${NC}"
		 fi
              done      
          else 
           echo "map $eth_name ${internal_ip}.1/24 -> $last_ip/32 "   >> /etc/ipnat.rules 
       fi
	/etc/rc.d/ipnat restart
	mkdir -p $OVPN/ssl
	mkdir -p $OVPN/tmp
	. ./vars
	echo -e "${blue}Creating keys${NC}"
	export KEY_SIZE=1024
	./clean-all > /dev/null; if [ $? -ne 0 ];then echo -e "${red}Can't clean all keys${NC}"; exit 1; fi
	./build-ca > /dev/null; if [ $? -ne 0 ];then echo -e "${red}Can't build ca key${NC}"; exit 1; fi 
	./build-dh > /dev/null; if [ $? -ne 0 ];then echo -e "${red}Can't build dh key${NC}"; exit 1; fi 
	echo "unique_subject = no" > ./keys/index.txt.attr
	./$buildserverkey > /dev/null;if [ $? -ne 0 ];then echo -e "${red}Can't build server key${NC}"; exit 1; fi
	cat keys/index.txt.attr|sed 's/\(.*=.*\)yes/\1no/p' >> keys/index.txt.attr_
	mv keys/index.txt.attr_ keys/index.txt.attr
	cp keys/server.crt /usr/local/etc/openvpn/ssl
	cp keys/server.key /usr/local/etc/openvpn/ssl
	cp keys/ca.crt /usr/local/etc/openvpn/ssl
	cp keys/dh1024.pem /usr/local/etc/openvpn/ssl

echo "# Port to use
port 1194

# First is the gateway (jail ip; netmask; IP-range start; IP-range stop)
server-bridge 192.168.1.246 255.255.255.0 192.168.1.180 192.168.1.190

# Scripts to load unload bridging device
up /usr/local/etc/openvpn/up.sh
down /usr/local/etc/openvpn/down.sh

proto udp
dev tap
client-to-client
script-security 2
user nobody
group nobody
daemon
comp-lzo
comp-noadapt
persist-key
persist-tun
verb 5
mode server
tls-server
ping 10
ping-exit 90
tun-mtu 1500
fragment 1400
mssfix
tmp-dir /usr/local/etc/openvpn/tmp
writepid /var/run/openvpn.pid
key-direction 1
<dh>
`cat $OVPN/ssl/dh1024.pem`
</dh>
<ca>
`cat $OVPN/ssl/ca.crt`
</ca> 
<cert>
`cat $OVPN/ssl/server.crt`
</cert>
<key>
`cat $OVPN/ssl/server.key`
</key> 

#auth-user-pass-verify /home/scripts/openvpn/auth.pl via-env
#client-connect /home/scripts/openvpn/connect.pl
#client-disconnect /home/scripts/openvpn/disconnect.pl" > $OVPN/server.conf

echo "#!/bin/sh
# Setup Ethernet bridge
ifconfig bridge0 create
ifconfig bridge0 addm epair0b #this has to be the name of the virtual device and can differ. epair0b is also possible, check with ifconfig
ifconfig bridge0 addm \${dev}
ifconfig bridge0 inet 192.168.1.213/24 # the IP of your ovpn jail!
ifconfig \${dev} up
ifconfig bridge0 up" > $OVPN/up.sh
chmod +x $OVPN/up.sh

echo "#!/bin/sh
ifconfig bridge0 destroy" > $OVPN/down.sh
chmod +x $OVPN/down.sh

        /usr/local/etc/rc.d/openvpn restart || echo -e "${red}can't restart vpn${NC}"
fi
if [ $build_ch = 1 ];then 
export last_ip=`cat $OVPN/server.conf | sed -n 's/^local \([0-9.]*\)/\1/p'`
export port=`grep "^lport" $OVPN/server.conf | awk '{print $2}'`
export protocol_client="`grep "^proto" $OVPN/server.conf|awk '{ if ($2 == "udp")
         print "$2";
         else if ($2 ~ "tcp")
         print "tcp-client" }'`"
export comment="`grep fragment $OVPN/server.conf|sed -nE 's/(#)?.*/\1/p'`" 
fi
mkdir -p /home/admin/apache_mon/

echo $users|tr -s "," "\n"|while read USERNAME;do 
cd $main_dir
. ./vars
export KEY_CN=$USERNAME
export KEY_SIZE=1024
 ./build-key $USERNAME > /dev/null;if [ $? -ne 0 ];then echo -e "${red}Can't build $USERNAME key${NC}"; exit 1; fi
 mkdir -p $OVPN/$USERNAME
 cp keys/ca.crt $OVPN/$USERNAME
 cp keys/dh1024.pem $OVPN/$USERNAME
 cp keys/$USERNAME\.key $OVPN/$USERNAME
 cp keys/$USERNAME\.crt $OVPN/$USERNAME
 echo "remote $last_ip
dev tap
comp-lzo
comp-noadapt
#user nobody
#group nobody
client
verb 5
proto $protocol_client
rport $port
#log-append /var/log/openvpn.log
tun-mtu 1500
mssfix
route-method exe
route-delay 2
$comment fragment 1400
persist-key
persist-tun
#auth-user-pass
#writepid /var/run/openvpn.pid
nobind
key-direction 1
<ca>
`cat keys/ca.crt`
</ca>
<dh>
`cat keys/dh1024.pem`
</dh>
<cert>
`cat keys/$USERNAME\.crt`
</cert>
<key>
`cat keys/$USERNAME\.key`
</key> " > $OVPN/$USERNAME/client.ovpn
 cd $main_dir
done


echo -e "${blue}>>>server and client keys copied to /usr/local/etc/openvpn/{ssl,client}${NC}"
echo $users|tr -s "," "\n"|while read USERNAME;do
 echo -e "${green} Config -> ${OVPN}${USERNAME}/client.ovpn ${NC}"
done

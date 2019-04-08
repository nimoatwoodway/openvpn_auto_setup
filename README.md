# OpenVPN in tap/bridge mode in iocage jail

HowTo install and configure an freebsd / freenas iocage jail to access the whole lan (even avahi, bonjour broadcast) with openvpn in bridged mode.

Tested with Freenas 11.2-U3

This HowTo is based on this HowTo: https://www.ixsystems.com/community/resources/openvpn-in-tap-bridge-mode-in-iocage-jail.85/ extendet with the auto create script from here: https://github.com/Fazik/openvpn_auto_setup
Many thanks to the authors!

ATTENTION: In version 11.2-U3 there is a known bug which should be fixed in 11.2-U4
For now heres a fix: https://www.ixsystems.com/community/threads/openvpn-issues-in-new-jails-after-11-1.59828/post-505700

## Create Jail
Create a jail with advances properties and these parameters:

* Release (I took newest available 11.2)
* VNET enabled
* IPv4 Interface vnet0
* Fixed IP
* Default Router IP address
* Auto-start enabled
* Custom Properties -> allow_tun enabled


## Install OpenVPN, create certificates and user profile in the newly created jail

Install dependencies, download this repo, switch to folder and run the commmand:

```
pkg install git
portsnap fetch && portsnap extract
git clone https://github.com/nimoatwoodway/openvpn_auto_setup.git
cd openvpn_auto_setup
```
### Run script
Thanks to Fazik for his script https://github.com/Fazik/openvpn_auto_setup. I've adjusted it a little to work in bridge mode.

```
/bin/sh openvpn_freebsd.sh [-i ] [-p ] [-u user1,user2...] [-d] [-t]
```
**-i** IP where to listen (default last)<br> 
**-p** Port on which listen(default 1194)<br>
**-u** A list of users separated by commas(default client)<br>
**-c** Duplicate cn(defaul off)<br>
**-t** Use tcp(default udp)<br>
**-d** Do not rebuild server keys and configs may be used to recreate or create new client keys

After successfull end You can get client config at ```/usr/local/etc/openvpn/$username/client.ovpn```

### Adjust some files to meet your network parameters
For a goog explanation what to do here: https://www.ixsystems.com/community/resources/openvpn-in-tap-bridge-mode-in-iocage-jail.85/

```
vi /usr/local/etc/openvpn/server.conf
```

```
vi /usr/local/etc/openvpn/up.sh
```

### Start/Restart Service
```
service openvpn restart
```
## You're done
Copy the client.ovpn from ```/usr/local/etc/openvpn/$username/client.ovpn``` and import into your prevered OpenVpn Client (Viscosity for MacOS in my case).

## Easy as Schnitzel isn't it?

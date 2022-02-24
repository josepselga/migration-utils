#!/bin/bash

#Screen colour constants
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
LIGHT_BLUE='\033[0;34m'
NC='\033[0m'

tmpPath="./tmpFiles"
SSH_KEY_SCRIPT="$(dirname "$0")/set_up_ssh_keys.sh"

filesToCheckCore=("/etc/raddb/eap.conf"
            "/etc/raddb/modules/opennac"
            "/etc/raddb/sites-available/inner-tunnel"
            "/etc/postfix/main.cf"
            "/etc/postfix/generic"
            "/usr/share/opennac/api/application/configs/application.ini"
            "/etc/filebeat/filebeat.yml"
)

filesToCheckAnalytics=(
)

filesChanged=()

noRetrievedFiles=()

# OpenNAC 1.2.1 migration to 1.2.2

check_changes() {
    
    #for i in **; do [[ -f "$i" ]] && md5sum "$i" > "$i".md5; done
    #$confFile=$1
    #$local="/files/$2"
    #$file=$(basename $1)
    #$localFile=$local$file
    
    if  [ -f $1 ]; then
        
        #diff <(md5sum opennac) <(md5sum opennac.md5)
        #cat opennac | tr -d '[:space:]' > opennac_cut

        if diff <(cat $1 | tr -d '[:space:]' | md5sum) <(cat $2 | tr -d '[:space:]' | md5sum) | grep '.*' > /dev/null; then
            #echo "Changes detected on --> " $1
            filesChanged+=($i)
        fi
    
    else
        echo "File " $(basename $1) " not find on files folder"
    fi
}

checkPackages(){
    ovaPackages=(WARNING. This system is for the use of authorized users only. Be careful !! iproute tcl-devel avahi-libs libcap libcap perl-DBD-MySQL  rpm-libs texlive-texmf-errata-latex plymouth-scripts libreport-plugin-ureport libmcrypt gamin hal-libs abrt-addon-ccpp libpcap vim-minimal psutils udev netpbm-progs openldap lvm2-libs nagios-plugins-dig kernel redis dhclient texlive-utils bind-utils systemtap-runtime opennac-freeradius-module numactl libX11 iwl6000g2a-firmware iputils apr iwl1000-firmware mpfr attr rarian pm-utils dosfstools libgnomecanvas gstreamer-tools liberation-fonts-common libXinerama system-config-keyboard gtk2-engines libSM rubygem-mixlib-cli system-config-date-docs biosdevname rubygem-treetop notification-daemon cpuspeed rubygem-rake python-paramiko rubygem-echoe python-babel bash ustr blktrace libyaml db4 pam_passwdqc screen xz-libs compat-xcb-util samba4-libs file-libs unzip php-common cpio php-pdo perl-Pod-Simple dhcp-common php-devel glibc-common libgearman sqlite pygtk2 libstdc++ rhpl tcp_wrappers dejavu-lgc-sans-mono-fonts db4-utils filesystem iptables usermode gnumeric ca-certificates libXfont pinentry libssh2 ghostscript make libattr libreport-python mysql-server curl freeradius-python rpm-python filebeat gzip abrt-tui collectd ConsoleKit sos php-mcrypt abrt-addon-kerneloops hiredis logrotate readline cpp kernel texlive-texmf-errata-fonts lzo upstart tokyocabinet krb5-libs libgomp poppler-data libxml2-python initscripts php-gd device-mapper-event-libs opennac-php-pecl-expect satyr libgpg-error device-mapper-event nagios-plugins man binutils nagios-plugins-mysql hunspell texlive-texmf-fonts libproxy-python lvm2 boost-program-options libICE openssh-server poppler vim-enhanced texlive-texmf-latex cups-libs libedit yum-utils iptables-ipv6 pinfo mod_ssl ruby acl opennac-api libusb1 jasper-libs opennac-utils xorg-x11-drv-ati-firmware hunspell-pt iwl3945-firmware libXdamage plymouth xml-common kernel-devel opennac-dhcp-helper-reader policycoreutils cloog-ppl pygtk2-libglade ed iwl6000-firmware system-config-language eggdbus libxslt cryptsetup-luks-libs desktop-file-utils libuser-python setserial hal gnome-user-docs rfkill crda httpd-tools cyrus-sasl diffutils mozilla-filesystem words readahead libXt libXrender fontpackages-filesystem libXcursor ORBit2 libXft pyxf86config ipw2100-firmware kernel xulrunner gpg-pubkey-c105b9de gnome-icon-theme gtk2 libXres setuptool system-config-date rubygem-mixlib-authentication python-meh rubygem-bunny bfa-firmware gpm-libs libcanberra-gtk2 rubygem-mime-types at metacity smartmontools python-crypto usbutils net-snmp-libs rubygem-ohai gpgme python-setuptools rubygem-net-ssh-gateway ncurses-libs fipscheck automake audit-libs grub python-keyczar ansible zlib json-c tcsh patch gawk ntsysv pygpgme libtalloc efibootmgr pytalloc btparser findutils lsof krb5-server krb5-workstation libsemanage centos-indexhtml php-pear gdbm libthai opennac-zend libjpeg-turbo perl-libs libevent-devel p11-kit kernel-headers php-mysql libtiff hwdata php-pecl-ssh2 libselinux-utils glibc boost-system dmidecode libcom_err php-pecl-radius grubby libudev expect coreutils-libs dejavu-fonts-common iwl100-firmware dejavu-sans-mono-fonts nss-sysinit timeconfig selinux-policy atk xorg-x11-font-utils python net-tools libgearman-devel libreport-compat memcached info abrt-libs pam freeradius-ldap popt libreport-plugin-mailx dash python-netaddr libreport-plugin-kerneloops libpciaccess collectd-mysql libreport-cli liblzf sed abrt-python libmemcached bind-libs redhat-rpm-config libnih pixman p7zip e2fsprogs-libs bind bzip2 util-linux-ng newt-python telnet device-mapper openldap-servers dracut-kernel aic94xx-firmware nagios-plugins-http ntpdate python-pycurl glibc-devel nmap gcc libproxy gearmand openssh-clients texlive rsyslog texlive-latex checkpolicy polkit yum-plugin-security selinux-policy-targeted mysql-libs freeradius-openNAC sysstat ruby-irb rubygem-rspec-expectations scl-utils opennac-api-doc kernel-devel rubygem-rake-compiler libvorbis opennac-admonportal ppl libglade2 nano opennac-gauth libtool-ltdl iwl5150-firmware MAKEDEV libselinux-python cryptsetup-luks vconfig python-slip rdate apr-util-ldap mdadm libsndfile system-config-keyboard-base system-config-firewall-base ivtv-firmware mailcap libXext atmel-firmware cracklib-dicts libIDL libXi libreport-gtk pango gnome-vfs2 compat-readline5 system-config-users-docs control-center-filesystem system-config-firewall-tui rubygem-json gnome-python2-canvas wireless-tools rubygem-moneta mingetty libreport-newt rubygem-systemu pkgconfig libcanberra b43-openfwwf rubygem-rest-client zenity rubygem-activesupport gpg-pubkey rng-tools lm_sensors-libs ruby-rdoc ncurses-base rubygem-uuidtools libidn-devel rubygem-net-ssh-multi fipscheck-lib autoconf chkconfig slang python-pyasn1 tcpdump sshpass fprintd-pam augeas-libs nc audit elfutils-libelf python-iniparse gdb tmpwatch libldb kernel-devel cyrus-sasl-lib xmlrpc-c portreserve time pciutils-libs samba4-winbind dialog grep php-cli ql2400-firmware libxcb texlive-texmf kernel perl-version libnl libevent-headers libgcc libpng kpathsea libreport-filesystem libtar php-pecl-memcache tzdata php-process nspr newt snappy libfontenc libacl sysvinit-tools tcl libuuid p11-kit-trust kbd-misc phantomjs coreutils elfutils nss rrdtool tar mailx expect-devel dbus-glib python-libs kbd ghostscript-fonts libreport-plugin-rhtsupport dmraid freeradius-utils ncurses libreport php-pecl-igbinary shadow-utils rpm usermode-gtk php-soap hdparm fontconfig yum python-iwlib opennac-sample-openldap libXau pciutils libsepol libreport-plugin-logger collectd-rrdtool fprintd abrt php-pecl-redis4 xmlrpc-c-client bzip2-libs abrt-addon-python dbus pcmciautils python-dialog iw libss lcms-libs procps dhcp libidn device-mapper-libs netpbm libcap-ng openssh opennac-winexe kpartx nagios-plugins-procs python-urlgrabber lua glibc-headers texlive-texmf-errata-dvips irqbalance jemalloc libproxy-bin which kexec-tools php-pecl-gearman microcode_ctl texlive-dvips sudo tex-preview abrt-cli man-pages-es-extra pth postgresql-libs libdbi nss-tools opennac-healthcheck freetype rubygem-rspec-mocks ethtool man-pages-overrides hunspell-en opennac-captive-portal libdrm libogg iwl5000-firmware apr-util iwl6050-firmware libXcomposite libtdb iwl4965-firmware libutempter rarian-compat mtr linux-firmware hal-info docbook-dtds authconfig-gtk flac b43-fwcutter cronie-anacron gstreamer prelink groff cracklib-python cairo cracklib liberation-sans-fonts zd1211-firmware libXrandr gnome-keyring gdk-pixbuf2 avahi-glib ipw2200-firmware system-config-users hicolor-icon-theme gnome-themes rubygems gnome-python2 rubygem-mixlib-config sound-theme-freedesktop rubygem-abstract parted pulseaudio-libs kernel-devel system-config-network-tui libnotify rubygem-diff-lcs man-pages acpid httpd rubygem-highline setup virt-what python-httplib2 rubygem-rspec busybox man-pages-es python-crypto2.6 rubygem-allison python-jinja2 rubygem-chef libselinux authconfig python-six wget PyYAML libxml2 net-snmp-utils psacct yum-metadata-parser libpcap-devel expat xcb-util libkadm5 elfutils-libs cyrus-sasl-plain samba4-common tcp_wrappers-libs strace samba4 pcre pygobject2 freeradius libtasn1 texlive-texmf-errata perl-Module-Pluggable postfix libevent perl centos-release perl-DBI xz vim-filesystem php-pecl-apc shared-mime-info nss-softokn-freebl php-ldap nss-util mysql dbus-libs libfprint php-snmp xz-lzma-compat libblkid libgsf file zip ql2500-firmware redhat-logos nss-softokn goffice basesystem openssl urw-fonts dmraid-events libreport-plugin-reportuploader freeradius-mysql module-init-tools yum-plugin-fastestmirror yajl ConsoleKit-libs crontabs python-dmidecode opennac-dojo alsa-lib gnutls openldap-clients keyutils-libs vim-common libXpm dracut nagios-common libuser device-mapper-persistent-data texlive-texmf-dvips python-ethtool ntp openjpeg-libs e2fsprogs libusb python-argparse gnupg2 nxlog-ce ruby-libs sg3_utils-libs kernel rubygem-rspec-core plymouth-core-libs hunspell-es epel-release rubygem-polyglot libart_lgpl rubygem-mixlib-log bc traceroute sgml-common eject gnome-doc-utils-stylesheets m4 cronie libXtst libXfixes GConf2 rootfiles yelp xdg-utils rubygem-net-ssh libwnck bridge-utils libaio rubygem-erubis libasyncns sgpio quota firstboot ledmon rubygem-yajl-ruby python-markupsafe passwd python-simplejson libffi alsa-utils libcurl-devel dbus-python libtevent rsync samba4-winbind-clients libgcrypt php perl-Pod-Escapes kernel-devel libevent-doc less libX11-common php-xml mlocate psmisc pycairo glib2 net-snmp startup-notification gmp)
    
    echo -e "\n${YELLOW}Checking Installed packages...${NC}"
    packagesInstalled=$(ssh root@$1 "rpm -qa | sed -e s/-[0-9].*//" 2>&1)
    packagesInstalledA=($packagesInstalled)

    if [ ${#ovaPackages[@]} != ${#packagesInstalledA[@]} ]; then
        echo -e "${RED}Non Standard packages Installed: ${NC}"
        echo -e  ${ovaPackages[@]} ${packagesInstalledA[@]} | tr ' ' '\n' | sort | uniq -u
    else
        echo -e "${GREEN}No non Standard packages Installed: ${NC}"
    fi

    echo -e '\n'
}


post_install_noMove() {
      
    for sample in $(find /usr/share/opennac/ -name *.ini.sample)
    do
            oldini=$(echo ${sample} | sed 's_.sample__')
            diff=$(diff ${sample} ${oldini} 1>/dev/null; echo $?)
            if [ "${diff}" -eq 1 ] && [[ "${oldini}" != *"otp/config.ini" ]]
            then
                    echo -e "\n${oldini}"
            fi
    done
}

node='NO-TARGET'
password="opennac"
type="core"

while getopts n:t:p: flag
do
    case "${flag}" in
        n) node=${OPTARG};;
        t) type=${OPTARG};;
        p) password=${OPTARG};;
    esac
done

## Comprovar modificaciones de la instalacion 
case $type in

  ## If Core:
  core)
    type="Core"
    filesToCheck=("${filesToCheckCore[@]}")  
    packagesToCheck="./checkFiles/packagesCore"
    ;;

  ##If Analytics:
  analytics)
    type="Analytics"
    filesToCheck=("${filesToCheckAnalytics[@]}")
    packagesToCheck="./checkFiles/packagesAnalytics"  
    ;;
esac

if [[ $type != "Core" ]] && [[ $type != "Analytics" ]]; then
    echo -e "\n${RED}Wrong Tagret type, specify \"core\" or \"analytics\"${NC}\n"
    exit
fi

$SSH_KEY_SCRIPT "$node" "$password" 

echo -e "\n${YELLOW}Checking installation files...${NC}"
for i in "${filesToCheck[@]}"; do
    
    if scp root@$node:$i $tmpPath/$(basename $i)&> /dev/null; then
        check_changes "./checkFiles/$type/$(basename $i)" "$tmpPath/$(basename $i)"
        rm -rf "$tmpPath/$(basename $i)"
        #echo "$tmpPath/$(basename $i)"
    else
        #echo -e "${RED}Can't retrieve the file $i for host $node${NC}"
        noRetrievedFiles+=("$i")
    fi
done

if [ ${#filesChanged[@]} -eq 0 ]; then
    echo -e "${GREEN}No files appear to be modified based on OVA.${NC}\n"
else
    echo -e "${RED}The following files appear to be modified based on OVA:${NC}"
    for z in "${filesChanged[@]}"; do
        echo "$z"
    done
    echo -e "\n"
fi


if [[ $type == "Core" ]]; then
    echo -e "\n${YELLOW}Checking opennac .sample files...${NC}"
    echo -e "${RED}The following files appear to be modified based on .sample:${NC}"

    ssh root@$node "$(typeset -f post_install_noMove); post_install_noMove" 
fi

if (( ${#noRetrievedFiles[@]} )); then
    echo -e "\n${RED}The following files can't be retrieved:${NC}"
    for z in "${noRetrievedFiles[@]}"; do
        echo "$z"
    done
fi

checkPackages $node
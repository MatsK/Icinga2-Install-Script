#!/bin/bash
#
# Icinga2 Install Script for Ubuntu 14.04 LTS
# Version 08-07-2015
# Written by Malariuz <malariuz@gmx.de>
#

### Check for dialog, install if not found
export DEBIAN_FRONTEND=noninteractive
if [ $(dpkg-query -W -f='${Status}' dialog 2>/dev/null | grep -c "ok installed") -eq 0 ];
then
	echo "Installing Dialog..."
	apt-get -qq install dialog -y > /dev/null 2>&1
fi
##TODO Check for debconf-set-selections

### Temp files
INPUT="/tmp/input.tmp"
OUTPUT="/tmp/output.tmp"
SQLPW="/tmp/mysql.tmp"
IDOPW="/tmp/ido.tmp"
CUIPW="/tmp/cui.tmp"
#trap "rm $OUTPUT; rm $INPUT; rm $SQLPW; rm $IDOPW; rm $CUIPW; exit" 0 1 2 5 15

BT="Icinga2 Install Script"

### Dialog functions
function password(){
	local t=${1}
	local tt=${2}
	local pw=${3}
	dialog --backtitle "${BT}" --title "${t}" --clear --insecure --passwordbox "${tt}" 10 30 2> "${pw}"
}

function display(){
	local h=${1-10}
	local w=${2-41}
	local t=${3-Output}
	dialog --backtitle "${BT}" --title "${t}" --clear --msgbox "$(<$OUTPUT)" ${h} ${w}
}

function progress(){
	local t=${1}
	dialog --backtitle "${BT}" --title "${t}" --progressbox 16 80; sleep 1;
}

### Nagios Plugin install helper
function nagios_plugins() {
	dialog --title "Nagios Plugins" \
		--yesno "\nInstall Nagios plugins?\n\n-Provides several check commands" 10 40
	ret=${?}
	if [ "$ret" -eq "255" ]
		then
			echo "Canceled"
			exit 255
	fi
	if [ "$ret" -eq "0" ]
		then
			apt-get -y install nagios-plugins 2>&1 | progress "Install Nagios plugins"
	fi
}

### Icinga2 IDO-MySQL
function ido_mysql() {
	#TODO: password box for SQL root pw, when script was interupted
	password "IDO-MySQL Password" "\nEnter a password for icinga2-ido-mysq user" "$IDOPW"
	debconf-set-selections <<< "icinga2-ido-mysql icinga2-ido-mysql/dbconfig-install boolean true"
	debconf-set-selections <<< "icinga2-ido-mysql icinga2-ido-mysql/enable boolean true" ##IDO Icinga feature enable
	debconf-set-selections <<< "icinga2-ido-mysql icinga2-ido-mysql/mysql/admin-pass password $(cat $SQLPW)"
	debconf-set-selections <<< "icinga2-ido-mysql icinga2-ido-mysql/mysql/app-pass password $(cat $IDOPW)"
	debconf-set-selections <<< "icinga2-ido-mysql icinga2-ido-mysql/app-password-confirm password $(cat $IDOPW)" ##IDO DB PW confirm
	apt-get -qq -y install icinga2-ido-mysql | progress "Install Icinga2-IDO-MySQL"
	icinga2 feature enable ido-mysql | progress "Enable Icinga2 ido-mysql feature"
	service icinga2 restart | progress "Restarting Icinga2 service"
}

### Icinga2 Classic UI
function icinga2_classicui() {
	password "ClassicUI Password" "\nEnter a password for icingaadmin user" "$CUIPW"
	debconf-set-selections <<< "icinga2-classicui icinga2-classicui/adminpassword password $(cat $CUIPW)"
	debconf-set-selections <<< "icinga2-classicui icinga2-classicui/adminpassword-repeat password $(cat $CUIPW)"
	apt-get -y install icinga2-classicui | progress #TODO annoying messages to be destoryed
}

### Icinga Web
function icinga_web() {
	apt-get -y install icinga-web icinga-web-config-icinga2-ido-mysql
	echo "Icinga Web wird installiert."
	/usr/lib/icinga-web/bin/clearcache.sh
	service mysql restart 
	service icinga2 restart 
	service apache2 restart
}

### Icinga2 Web2
function icinga_web2() {
	apt-get -y install make git zend-framework php5 libapache2-mod-php5 php5-mcrypt apache2-mpm-prefork apache2-utils php5-mysql php5-ldap php5-intl php5-imagick php5-gd
	echo "Icingaweb2 wird installiert."
	a2enmod cgi
	a2enmod rewrite
	service apache2 restart
	echo "include_path = ".:/usr/share/php:/usr/share/php/libzend-framework-php/"" >> /etc/php5/cli/php.ini
	echo "include_path = ".:/usr/share/php:/usr/share/php/libzend-framework-php/"" >> /etc/php5/apache2/php.ini
	cd /usr/src
	git clone http://git.icinga.org/icingaweb2.git
	
	#Anlegen der IcingaWeb2 mysql Datenbank
	echo ""
	echo > ~/icingaweb2db.sql
	echo "CREATE DATABASE icingaweb;" >> ~/icingaweb2db.sql
	echo "CREATE USER icingaweb@localhost IDENTIFIED BY 'icingaweb';" >> ~/icingaweb2db.sql
	echo "GRANT ALL PRIVILEGES ON icingaweb.* TO icingaweb@localhost;" >> ~/icingaweb2db.sql
	echo "FLUSH PRIVILEGES;" >> ~/icingaweb2db.sql
	echo
	echo "Kennwort für mysql-Nutzer root eingeben:"
	echo
	mysql -u root -p < ~/icingaweb2db.sql
	
	#Schema import
	clear
	echo ""
	echo "Schema Import /icingaweb2/etc/schema/mysql.schema.sql"
	echo "Kennwort für mysql-Nutzer root eingeben:"
	echo
	mysql -u root -p icingaweb < /usr/src/icingaweb2/etc/schema/mysql.schema.sql

	cd /usr/src/
	mv icingaweb2 /usr/share/icingaweb2
	/usr/share/icingaweb2/bin/icingacli setup config webserver apache --document-root /usr/share/icingaweb2/public > /etc/apache2/conf-available/icingaweb2.conf

	addgroup --system icingaweb2
	usermod -a -G icingaweb2 www-data

	a2enconf icingaweb2.conf
	service apache2 reload

	/usr/share/icingaweb2/bin/icingacli setup config directory
	
	echo "date.timezone =Europe/Berlin" >> /etc/php5/apache2/php.ini
	service apache2 restart
}

function basic_inst(){
	echo "-- Installing Basic System --\n\n-Add Icinga2 repository\n-Update and upgrade packages\n-Install Apache2 & MySQL Server\n\nPress Enter to begin" >$OUTPUT
	display 12 60 "Install Basic System"
	password "MySQL Root Password" "\nEnter a password for root user" "$SQLPW"
	## Add Icinga2 repo and update/upgrade packages
	add-apt-repository -y ppa:formorer/icinga 2>&1 | progress "Add Icinga2 repository"
	apt-get update 2>&1 | progress "Update repositories"
	apt-get -y upgrade 2>&1 | progress "Upgrade Ubuntu system"
	## Install apache2
	apt-get -y install apache2 2>&1 | progress "Install Apache2 server"
	## Install mysql server 5.5 with given password
	debconf-set-selections <<< "mysql-server-5.5 mysql-server/root_password password $(cat $SQLPW)"
	debconf-set-selections <<< "mysql-server-5.5 mysql-server/root_password_again password $(cat $SQLPW)"
	apt-get -y install mysql-server-5.5 2>&1 | progress "Install MySQL server"
}

function icinga2_inst(){
	echo "-- Installing Icinga2 --\n\n-Install Icinga2 Core\n-Add user www-data to nagios group\n\nPress Enter to begin" >$OUTPUT
	display 12 60 "Install Icinga2 Core"
	apt-get -y install icinga2 2>&1 | progress "Install Icinga2 Core"
	icinga2 feature enable command 2>&1 | progress "Enable Icinga2 command feature"
	usermod -a -G nagios www-data > /dev/null 2>&1
	service apache2 restart 2>&1 | progress "Restart Apache2 server"
	service icinga2 restart 2>&1 | progress "Restart Icinga2 Core"
	nagios_plugins
}

function webui_inst(){
	dialog --backtitle "${BT}" \
			   --checklist "Choose UIs for Icinga2" 15 50 8 \
			   01 "Icinga2 Classic UI" on\
			   02 "IcingaWeb" off\
			   03 "IcingaWeb2" off 2>"${INPUT}"
	ret="$(cat $INPUT)"
	case "$ret" in
		"01") echo "Classic UI"
				icinga2_classicui
			;;
		"01 02") echo "Classic UI & IcingaWeb"
				icinga2_classicui
				ido_mysql
				#icinga_web
			;;
		"01 02 03") echo "Alle UIs"
				icinga2_classicui
				ido_mysql
				#icinga_web
				#icinga_web2
			;;
		"02") echo "IcingaWeb"
				ido_mysql
				#icinga_web
			;;
		"02 03") echo "IcingaWeb & Web2"
				ido_mysql
				#icinga_web
				icinga_web2
			;;
		"01 03") echo "Classic UI & Web2"
				icinga2_classicui
				ido_mysql
				#icinga_web2
			;;
		"03") echo "Web2"
				ido_mysql
				#icinga_web2
			;;
			*) echo "No UI"
			;;
	esac
}

function graph_inst(){
}

while true
do

### Main Menu
dialog --clear --help-button --backtitle "Icinga2 Install Script" \
--title "[ --MAIN MENU-- ]" \
--menu "Your can use the UP/DOWN arrow keys, the first \n\
letter of the choice as a hot key, or the \n\
number keys 1-9 to choose an option.\n\
Choose the TASK" 15 50 6 \
Basic "Install Basic System" \
Icinga2 "Install Icinga2" \
WebUI "Install WebUIs" \
Graph "Install Graph Tools" \
IdoTest "Test--IDO" \
Exit "Exit to the shell" 2>"${INPUT}"

menuitem=$(<"${INPUT}")

case $menuitem in
	Basic) basic_inst;;
	Icinga2) icinga2_inst;;
	WebUI) webui_inst;;
	Graph) graph_inst;;
	IdoTest) ido_mysql;;
	Exit) clear; echo "Bye"; break;;
esac

done
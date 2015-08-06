#!/bin/bash
_temp="/tmp/answer.$$"
### Icinga2 Installation
icinga2_inst() {
	apt-get -y install icinga2
	echo "Icinga2 wird installiert."
	icinga2 feature enable command
	usermod -a -G nagios www-data
	service apache2 restart
	service icinga2 restart
}

### Nagios Plugins
nagios_plugins() {
	dialog --title "Icinga 2 Features" \
		--yesno "\n Nagios Plugins installieren?\n\n --Beinhaltet diverse Check-Commands" 10 40
	antwort=${?}
	if [ "$antwort" -eq "255" ]
		then
			echo "Canceled"
			exit 255
	fi
	if [ "$antwort" -eq "1" ]
		then
			echo "Nagios Plugins werden nicht installiert. Weiter im Programm"
	fi	
	if [ "$antwort" -eq "0" ]
		then
			echo "Nagios Pluings werden installiert"
			apt-get -y install nagios-plugins
	fi
}

### Icinga2 IDO-MySQL
ido_mysql() {
	##TODO echo PW
	apt-get -y install icinga2-ido-mysql
	echo "Icinga2 IDO MySQL wird installiert."
	icinga2 feature enable ido-mysql
	service icinga2 restart
}

### Icinga2 Classic UI
icinga2_classicui() {
	apt-get -y install icinga2-classicui
	echo "Icinga 2 Classic UI wird installiert."
}

### Icinga Web
icinga_web() {
	apt-get -y install icinga-web icinga-web-config-icinga2-ido-mysql
	echo "Icinga Web wird installiert."
	/usr/lib/icinga-web/bin/clearcache.sh
	service mysql restart 
	service icinga2 restart 
	service apache2 restart
}

### Icinga2 Web2
icinga_web2() {
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


### Icinga2 UIs
icinga2_ui() {
	#Dialog
	dialog --backtitle "Icinga2 UIs" \
			   --checklist "UI für Icinga2 auswählen" 15 50 8 \
			   01 "Icinga2 Classic UI" on\
			   02 "IcingaWeb" off\
			   03 "IcingaWeb2" off 2>$_temp
	result=`cat $_temp`
	case "$result" in
		"01") echo "Classic UI"
				icinga2_classicui
			;;
		"01 02") echo "Classic UI & IcingaWeb"
				icinga2_classicui
				ido_mysql
				icinga_web
			;;
		"01 02 03") echo "Alle UIs"
				icinga2_classicui
				ido_mysql
				icinga_web
				icinga_web2
			;;
		"02") echo "IcingaWeb"
				ido_mysql
				icinga_web
			;;
		"02 03") echo "IcingaWeb & Web2"
				ido_mysql
				icinga_web
				icinga_web2
			;;
		"01 03") echo "Classic UI & Web2"
				icinga2_classicui
				ido_mysql
				icinga_web2
			;;
		"03") echo "Web2"
				ido_mysql
				icinga_web2
			;;
			*) echo "No UI"
			;;
	esac
}


clear
## Icinga2 Repo hinzufügen
echo "Aktualsierung der Paketquellen"
echo ""
echo "-- Den Import der Icinga2 Quellen mit Enter bestätigen --"
echo ""
echo ""
add-apt-repository ppa:formorer/icinga
apt-get update
apt-get -y upgrade
apt-get -y install dialog
clear
echo "Installation Apache & MySQL Server"
echo ""
echo "-- MySQL verlangt die Vergabe des MySQL Root User Passwortes --"
echo ""
apt-get -y install apache2
apt-get -y install mysql-server
clear
echo "Icinga 2 Installation"
echo ""
icinga2_inst
nagios_plugins
icinga2_ui
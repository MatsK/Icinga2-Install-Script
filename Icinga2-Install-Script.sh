#!/bin/bash
#
# Icinga2 Install Script for Ubuntu 14.04 LTS
# Version 08-07-2015
# Written by Malariuz <malariuz@gmx.de>
#
export DEBIAN_FRONTEND=noninteractive
if [ $(dpkg-query -W -f='${Status}' dialog 2>/dev/null | grep -c "ok installed") -eq 0 ];
then
  apt-get -qq install dialog -y > /dev/null 2>&1
fi

INPUT="/tmp/input.tmp.$$"
OUTPUT="/tmp/output.tmp.$$"
PASSWORD="/tmp/password.tmp.$$"

BT="Icinga2 Install Script"

#trap "rm $OUTPUT; rm $INPUT; rm $PASSWORD; exit" 0 1 2 5 15

function password(){
	local h=${1-10}
	local w=${2-41}
	local t=${3}
	local tt=${4}
	dialog --backtitle "${BT}" --title "${t}" --clear --insecure --passwordbox "${tt}" 10 30 2> $PASSWORD
}

function display(){
	local h=${1-10}
	local w=${2-41}
	local t=${3-Output}
	dialog --backtitle "Icinga2 Install Script" --title "${t}" --clear --msgbox "$(<$OUTPUT)" ${h} ${w}
}

function nagios_plugins() {
	dialog --title "Nagios Plugins" \
		--yesno "\nInstall Nagios plugins?\n\n-Provides several check commands" 10 40
	ret=${?}
	if [ "$ret" -eq "255" ]
		then
			echo "Canceled"
			exit 255
	fi
	if [ "$ret" -eq "1" ]
		then
	fi	
	if [ "$ret" -eq "0" ]
		then
			apt-get -y install nagios-plugins 2>&1 | dialog --title "Install Nagios plugins" --progressbox 16 80; sleep 1;
	fi
}

function basic_inst(){
	echo "-- Installing Basic System --\n\n-Add Icinga2 repository\n-Update and upgrade packages\n-Install Apache2 & MySQL Server\n\nPress Enter to begin" >$OUTPUT
	display 12 60 "Install Basic System"
	password 10 30 "MySQL Root Password" "\nEnter a password for root user"
	## Add Icinga2 repo and update/upgrade packages
	add-apt-repository -y ppa:formorer/icinga 2>&1 | dialog --title "Add Icinga2 repository" --progressbox 16 80; sleep 1;
	apt-get update 2>&1 | dialog --title "Update repositories" --progressbox 16 80; sleep 1;
	apt-get -y upgrade 2>&1 | dialog --title "Upgrade Ubuntu system" --progressbox 16 80; sleep 1;
	## Install apache2
	apt-get -y install apache2 2>&1 | dialog --title "Install Apache2 server" --progressbox 16 80; sleep 1;
	apt-get -y install mysql-server 2>&1 | dialog --title "Install MySQL server" --progressbox 16 80; sleep 1;
	mysqladmin -u root password "$(cat $PASSWORD)"
}

function icinga2_inst(){
	echo "-- Installing Icinga2 --\n\n-Install Icinga2 Core\n-Add user www-data to nagios group\n\nPress Enter to begin" >$OUTPUT
	display 12 60 "Install Icinga2 Core"
	apt-get -y install icinga2 2>&1 | dialog --title "Install Icinga2 Core" --progressbox 16 80; sleep 1;
	###icinga2 feature enable command 2>&1 | --dialog --progressbox 16 80; sleep 1;
	usermod -a -G nagios www-data > /dev/null 2>&1
	service apache2 restart 2>&1 | dialog --title "Restart Apache2 server" --progressbox 16 80; sleep 1;
	service icinga2 restart 2>&1 | dialog --title "Restart Icinga2 Core" --progressbox 16 80; sleep 1;
	nagios_plugins
}

while true
do

### Main Menu
dialog --clear --help-button --backtitle "Icinga2 Install Script" \
--title "[ --MAIN MENU-- ]" \
--menu "Your can use the UP/DOWN arrow keys, the first \n\
letter of the choice as a hot key, or the \n\
number keys 1-9 to choose an option.\n\
Choose the TASK" 15 50 5 \
Basic "Install Basic System" \
Icinga2 "Install Icinga2" \
WebUI "Install WebUIs" \
Graph "Install Graph Tools" \
Exit "Exit to the shell" 2>"${INPUT}"

menuitem=$(<"${INPUT}")

case $menuitem in
	Basic) basic_inst;;
	Icinga2) icinga2_inst;;
	WebUI) webui_inst;;
	Graph) graph_inst;;
	Exit) clear; echo "Bye"; break;;
esac

done
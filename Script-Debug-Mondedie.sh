#!/bin/bash
#
# Script original développé par BarracudaXT (BXT)
#
# cd /tmp
# git clone https://github.com/exrat/Script-Debug-MonDedie
# cd Script-Debug-MonDedie
# chmod a+x Script-Debug-Mondedie.sh & ./Script-Debug-Mondedie.sh
#

CSI="\033["
CEND="${CSI}0m"
CGREEN="${CSI}1;32m"
CRED="${CSI}1;31m"
CYELLOW="${CSI}1;33m"
CBLUE="${CSI}1;34m"

RAPPORT="/tmp/rapport.txt"
VERSION=$(cat /etc/debian_version)
NOYAU=$(uname -r)
DATE=$(date +"%d-%m-%Y à %H:%M")
PHP=$(php -v | cut -c 1-7 | grep PHP)

RUTORRENT="/var/www/rutorrent"
RUTORRENT_CONFFILE="/etc/nginx/sites-enabled"

if [[ $UID != 0 ]]; then
	echo -e "${CRED}Ce script doit être executé en tant que root${CEND}"
	exit
fi

chmod a+x zerocli.sh

function gen()
{
	if [[ -f $RAPPORT ]]; then
		echo -e "${CRED}\nFichier de rapport détecté${CEND}"
		rm $RAPPORT
		echo -e "${CGREEN}Fichier de rapport supprimé${CEND}"
	fi
	touch $RAPPORT
cat <<-EOF >> $RAPPORT

				###  Rapport pour ruTorrent généré le $DATE  ###

				Utilisateur ruTorrent => $USERNAME

				Debian $VERSION
				Kernel : $NOYAU
				$PHP

				EOF
if [[ $(grep "$USERNAME:" -c /etc/shadow) != "1" ]]; then
	echo -e "--> Utilisateur inexistant" >> $RAPPORT
	VALID_USER=0
else
	echo -e "--> Utilisateur $USERNAME existant" >> $RAPPORT
fi
}

function checkBin() # $2 utile pour faire une redirection dans $RAPPORT + Pas d'installation
{
	if ! [[ $(dpkg -s "$1" | grep Status ) =~ "Status: install ok installed" ]]  &> /dev/null ; then # $1 = Nom du programme
		if [[ $2 = 1 ]]; then
			echo -e "Le programme $1 n'est pas installé" >> $RAPPORT
		else
			echo -e "${CGREEN}\nLe programme${CEND} ${CYELLOW}$1${CEND}${CGREEN} n'est pas installé\nIl va être installé pour la suite du script${CEND}"
			sleep 2
			apt-get -y install "$1"
fi
	else
		if [[ $2 = 1 ]]; then
			echo -e "Le programme $1 est installé" >> $RAPPORT
		fi
	fi
}

function genRapport()
{
	 sh zerocli.sh "$RAPPORT"
}

function rapport()
{
	# $1 = Fichier
	if ! [[ -z $1 ]]; then
		if [[ -f $1 ]]; then
			if [[ $(wc -l < "$1") == 0 ]]; then
				FILE="--> Fichier Vide"
			else
				FILE=$(cat "$1")
			fi
		else
			FILE="--> Fichier Invalide"
		fi
	else
		FILE="--> Fichier Invalide"
	fi
	# $2 = Nom à afficher
	if [[ -z $2 ]]; then
		NAME="Aucun nom donné"
	else
		NAME=$2
	fi

	# $3 = Affichage header
	if [[ $3 == 1 ]]; then
		cat <<-EOF >> $RAPPORT


		......................................................................
		## $NAME
		......................................................................
		EOF
	fi
	cat <<-EOF >> $RAPPORT
	File : $1

	$FILE
	EOF
}

function testTorrent()
{
SCGI="$(sed -n '/^scgi_port/p' /home/"$USERNAME"/.rtorrent.rc | cut -b 23-)"
PORT_LISTENING=$(netstat -aultnp | awk '{print $4}' | grep -E ":$SCGI\$" -c)
RTORRENT_LISTENING=$(netstat -aultnp | sed -n '/'$SCGI'/p' | grep rtorrent -c)

cat <<-EOF >> $RAPPORT


......................................................................
## Test rTorrent & sgci
......................................................................
		EOF
# rTorrent lancé
if [[ "$(ps uU "$USERNAME" | grep -e 'rtorrent' -c)" == [0-1]  ]]; then
	echo -e "rTorrent down" >> $RAPPORT
else
	echo -e "rTorrent Up" >> $RAPPORT
fi

# socket
if (( PORT_LISTENING >= 1 )); then
    echo -e "Un socket écoute sur le port $SCGI" >> $RAPPORT
    if (( RTORRENT_LISTENING >= 1 )); then
        echo -e "C'est bien rTorrent qui écoute sur le port $SCGI" >> $RAPPORT
    else
        echo -e "Ce n'est pas rTorrent qui écoute sur le port $SCGI" >> $RAPPORT
    fi
else
        echo -e "Aucun programme n'écoute sur le port $SCGI" >> $RAPPORT
fi

# ruTorrent
if [[ -f $RUTORRENT/conf/users/$USERNAME/config.php ]]; then
		if [[ $(cat "$RUTORRENT"/conf/users/"$USERNAME"/config.php) =~ "\$scgi_port = $SCGI" ]]; then
			echo -e "Bon port SCGI renseigné dans le fichier config.php"  >> $RAPPORT
		else
			echo -e "Mauvais port SCGI renseigné dans le fichier config.php"  >> $RAPPORT
		fi
else
	echo -e "Répertoire utilisateur trouvé, mais fichier config.php inexistant"  >> $RAPPORT
fi

# nginx
if [[ $(cat $RUTORRENT_CONFFILE/rutorrent.conf) =~ $SCGI ]]; then
	echo -e "Les ports nginx et celui indiqué correspondent"   >> $RAPPORT
else
	echo -e "Les ports nginx et celui indiqué ne correspondent pas"   >> $RAPPORT
fi
echo ""
}

function remove()
{
	echo -e -n "${CGREEN}\nVoulez vous désinstaller Rhino ? (y/n):${CEND} "
	read -r RHINO
	if [ "$RHINO" = "y" ]  || [ "$RHINO" = "Y" ]; then
		apt-get remove -y rhino &>/dev/null
		echo -e "${CBLUE}Rhino a bien été désinstallé${CEND}"
	fi
}

clear
echo -e "${CBLUE}
                                      |          |_)         _|
            __ \`__ \   _ \  __ \   _\` |  _ \  _\` | |  _ \   |    __|
            |   |   | (   | |   | (   |  __/ (   | |  __/   __| |
           _|  _|  _|\___/ _|  _|\__,_|\___|\__,_|_|\___|_)_|  _|
${CEND}"
echo ""
echo -e "${CBLUE}                            Script de debug ruTorrent${CEND}"
echo ""
echo -e -n "${CGREEN}Rentrez le nom de votre utilisateur rTorrent:${CEND} "
read -r USERNAME
echo -e "${CBLUE}Merci de patienter quelques secondes...${CEND}"

gen ruTorrent "$USERNAME"
checkBin rhino

testTorrent

cat <<-EOF >> $RAPPORT


......................................................................
## rTorrent Activity
......................................................................
EOF
if [[ $VALID_USER = 0 ]]; then
	echo -e "--> Utilisateur inexistant" >> $RAPPORT
else
	echo -e "$(/bin/ps uU "$USERNAME" | grep -e rtorrent)" >> $RAPPORT
fi

cat <<-EOF >> $RAPPORT


......................................................................
## Irssi Activity
......................................................................
EOF
if ! [[ -f "/etc/irssi.conf"  ]]; then
	echo -e "--> Irssi non installé" >> $RAPPORT
else
	echo -e "$(/bin/ps uU "$USERNAME" | grep -e irssi)" >> $RAPPORT
fi

cat <<-EOF >> $RAPPORT


......................................................................
## .rtorrent.rc 
......................................................................
EOF
echo  "File : /home/$USERNAME/.rtorrent.rc" >> $RAPPORT ; echo "" >> $RAPPORT

if [[ $VALID_USER = 0 ]]; then
echo "--> Fichier introuvable (Utilisateur inexistant)" >> $RAPPORT
else
	if ! [[ -f "/home/$USERNAME/.rtorrent.rc" ]]; then
		echo "--> Fichier introuvable" >> $RAPPORT
	else
		cat "/home/$USERNAME/.rtorrent.rc" >> $RAPPORT
	fi
fi

cat <<-EOF >> $RAPPORT


......................................................................
## ruTorrent config.php $USERNAME
......................................................................
EOF
echo  "File : $RUTORRENT/conf/users/"$USERNAME"/config.php" >> $RAPPORT ; echo "" >> $RAPPORT

if [[ $VALID_USER = 0 ]]; then
	echo "--> Fichier introuvable (Utilisateur Inexistant)" >> $RAPPORT
else
	if [[ ! -f "$RUTORRENT/conf/users/$USERNAME/config.php" ]]; then
		echo "--> Fichier introuvable" >> $RAPPORT
	else
		cat $RUTORRENT/conf/users/"$USERNAME"/config.php >> $RAPPORT
	fi
fi

rapport /etc/init.d/"$USERNAME"-rtorrent "$USERNAME"-rtorrent 1

cd $RUTORRENT_CONFFILE
for VHOST in `ls`
do
        rapport $RUTORRENT_CONFFILE/$VHOST $VHOST 1
done
cd /tmp/Script-Debug-MonDedie

if [[ -f $RUTORRENT_CONFFILE/cakebox.conf ]]; then
	rapport /var/www/cakebox/config/"$USERNAME".php cakebox.config.Php 1
fi

rapport /var/log/nginx/rutorrent-error.log nginx.log 1
rapport /etc/nginx/nginx.conf nginx.conf 1

cd /etc/nginx/conf.d
for CONF_D in `ls`
do
        rapport /etc/nginx/conf.d/$CONF_D $CONF_D 1
done

cat <<-EOF >> $RAPPORT


......................................................................
## fichier pass nginx
......................................................................
EOF
echo  "Dir : /etc/nginx/passwd" >> $RAPPORT ; echo "" >> $RAPPORT
cd /etc/nginx/passwd
for PASS in `ls`
do
        echo "$PASS"  >> $RAPPORT
done

cat <<-EOF >> $RAPPORT


......................................................................
## fichier ssl nginx
......................................................................
EOF
echo  "Dir : /etc/nginx/ssl" >> $RAPPORT ; echo "" >> $RAPPORT
cd /etc/nginx/ssl
for SSL in `ls`
do
        echo "$SSL"  >> $RAPPORT
done
cd /tmp/Script-Debug-MonDedie
#rapport $RUTORRENT/conf/config.php rutorrent.config.Php 1

cat <<-EOF >> $RAPPORT


......................................................................
## fin
......................................................................
EOF
genRapport
remove


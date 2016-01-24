#!/bin/bash
set -x
APACHEDOCUMENTROOT=/var/www/html

#wordpress-specific
WORDPRESSDIR=$APACHEDOCUMENTROOT/wordpress
DBNAME="FILL IN THE BLANKS"
DBUSER="FILL IN THE BLANKS"
DBPASS="FILL IN THE BLANKS"
SITEPASS="FILL IN THE BLANKS"
SITETITLE="FILL IN THE BLANKS"
SITEEMAIL="FILL IN THE BLANKS"
WORDPRESSURL="http://localhost/wordpress"

#dyndns using changeip.com
CHANGEIP_LOGIN="FILL IN THE BLANKS"
CHANGEIP_PASSWORD="FILL IN THE BLANKS"
CHANGEIP_URL="FILL IN THE BLANKS"

sudo apt-get update
sudo apt-get -y upgrade
echo mysql-server mysql-server/root_password password $DBPASS | sudo debconf-set-selections
echo mysql-server mysql-server/root_password_again password $DBPASS | sudo debconf-set-selections
sudo env DEBIAN_FRONTEND=noninteractive apt-get -y -q install apache2 libapache2-mod-php5 mysql-server php5-mysql
if [ -d wordpresstemp ]; then
  rm -rf wordpresstemp
fi

mkdir wordpresstemp
cd wordpresstemp
wget -c http://wordpress.org/latest.tar.gz
tar xzf latest.tar.gz

if [ -d $WORDPRESSDIR]; then
  mkdir -p $WORDPRESSDIR
fi
sudo mv -f wordpress/* $WORDPRESSDIR

sudo chown -R www-data:www-data $APACHEDOCUMENTROOT
cd ..
rm -rf wordpresstemp
sudo cp $WORDPRESSDIR/wp-config-sample.php $WORDPRESSDIR/wp-config.php
sudo sed -i -e "s/database_name_here/$DBNAME/g" $WORDPRESSDIR/wp-config.php
sudo sed -i -e "s/username_here/$DBUSER/g" $WORDPRESSDIR/wp-config.php
sudo sed -i -e "s/password_here/$DBPASS/g" $WORDPRESSDIR/wp-config.php
sudo mkdir $WORDPRESSDIR/wp-content/uploads
sudo chmod 775 $WORDPRESSDIR/wp-content/uploads
SALTS=$(curl -s https://api.wordpress.org/secret-key/1.1/salt/)
while read -r SALT; do
SEARCH="define('$(echo "$SALT" | cut -d "'" -f 2)"
REPLACE=$(echo "$SALT" | cut -d "'" -f 4)
echo "... $SEARCH ... $SEARCH ..."
sudo sed -i "/^$SEARCH/s/put your unique phrase here/$(echo $REPLACE | sed -e 's/\\/\\\\/g' -e 's/\//\\\//g' -e 's/&/\\\&/g')/" $WORDPRESSDIR/wp-config.php
done <<< "$SALTS"

curl -sS https://getcomposer.org/installer | php
sudo mv composer.phar /usr/local/bin/composer
sudo composer init --stability dev --no-interaction
sudo composer config bin-dir bin
sudo composer config vendor-dir vendor
sudo mv composer.json /root/.composer 
sudo composer global require wp-cli/wp-cli
sudo bash -c "cd $WORDPRESSDIR && /root/.composer/bin/wp db create --allow-root"
sudo bash -c "cd $WORDPRESSDIR && /root/.composer/bin/wp core install --allow-root --title=\"$SITETITLE\" --admin_user=\"$DBUSER\" --admin_password=\"$SITEPASS\" --admin_email=\"$SITEEMAIL\" --url=$WORDPRESSURL  " 

sudo apachectl restart
sudo env DEBIAN_FRONTEND=noninteractive apt-get -y -q install ddclient
sudo bash -c "cat <<EOF > /etc/ddclient.conf
protocol=dyndns2
use=web,web=ip.changeip.com,web-skip=''
server=nic.changeip.com
login=$CHANGEIP_LOGIN
password=$CHANGEIP_PASSWORD
$CHANGEIP_URL
EOF
"
sudo systemctl restart ddclient
sudo ddclient -force


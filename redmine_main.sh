# Comments about this script

REDMINE_DIR='/var'
REDMINE_VERSION='6.0.3'

MYSQL_HOST='127.0.0.1'
MYSQL_DB='redmine'
MYSQL_USER='redmine'
MYSQL_PASSWD='toor'

APACHE_LOG_DIR='/var/log/apache2'

# Install dependencies
sudo apt-get install -y sudo vim build-essential libyaml-dev \
	default-mysql-server default-mysql-client libmariadb-dev \
	imagemagick libmagickwand-dev \
	apache2 libapache2-mod-passenger \
	ruby ruby-dev bundler

# Disable IPv6
sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1
sudo sysctl -w net.ipv6.conf.default.disable_ipv6=1
sudo sysctl -w net.ipv6.conf.lo.disable_ipv6=1

# MySQL conf
sudo mysql -e "CREATE DATABASE $MYSQL_DB CHARACTER SET utf8mb4; CREATE USER '$MYSQL_USER'@'$MYSQL_HOST' IDENTIFIED BY '$MYSQL_PASSWD'; GRANT ALL PRIVILEGES ON $MYSQL_DB.* TO '$MYSQL_USER'@'$MYSQL_HOST'; FLUSH PRIVILEGES; EXIT;"

# Install redmine
cd $REDMINE_DIR
sudo wget https://www.redmine.org/releases/redmine-$REDMINE_VERSION.tar.gz
sudo tar xf redmine-$REDMINE_VERSION.tar.gz
sudo rm redmine-$REDMINE_VERSION.tar.gz
sudo mv redmine-$REDMINE_VERSION redmine
cd redmine

# DB conf
echo "production:
  adapter: mysql2
  database: $MYSQL_DB
  host: $MYSQL_HOST
  username: $MYSQL_USER
  password: $MYSQL_PASSWD
  encoding: utf8mb4
  variables:
    transaction_isolation: \"READ-COMMITTED\"
" | sudo tee $REDMINE_DIR/redmine/config/database.yml 1>/dev/null

# Set up permissions
sudo chown -R www-data:$USER $REDMINE_DIR/redmine/
sudo chmod -R 775 $REDMINE_DIR/redmine/

# Redmine conf
cd $REDMINE_DIR/redmine/
sudo gem install bundler
bundle config set without "development test"
sudo bundle install

# Generate token
sudo bundle exec rake generate_secret_token
sudo RAILS_ENV=production bundle exec rake db:migrate

# Apache conf
echo "<VirtualHost *:80>
    ServerName redmine.plan.eu
    ServerAdmin banica@redmine.plan.eu
    DocumentRoot $REDMINE_DIR/redmine/public

    <Directory "$REDMINE_DIR/redmine/public">
        Allow from all
        Require all granted
        Options -MultiViews
    </Directory>

    ErrorLog $APACHE_LOG_DIR/redmine_error.log
    CustomLog $APACHE_LOG_DIR/redmine_access.log combined

    PassengerRuby /usr/bin/ruby
</VirtualHost>" | sudo tee /etc/apache2/sites-available/redmine.conf

# Enable site
sudo a2enmod passenger
sudo a2ensite redmine
sudo a2dissite 000-default
sudo systemctl restart apache2


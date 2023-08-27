#!/bin/bash
set -e
clear
# this project was set up as workspace context url with parameter to pass in as env var,
#   ex: https://gitpod.io/new/#DRUPAL_MAJOR=10/https://github.com/drubb/drupal-gitpod
#   but at prebuild context, then there is no env var, hence it default back to 9
#   now use gitpod project env var to specifically set, hence below to observe
#   original use case of using url parameter should work too since there is gitpod project env
echo current DRUPAL_MAJOR: "$DRUPAL_MAJOR"

# Create a MySQL user and Drupal database using default credentials for site install command.
while ! mysqladmin ping --silent; do
  sleep 1
done
mysql -u root -e "create database drupal"
mysql -u root -e "create user 'drupal'@'localhost' identified by 'drupal'"
mysql -u root -e "grant all privileges on drupal.* to 'drupal'@'localhost'"

# Speed up database write operations
mysql -u root -e "set global innodb_buffer_pool_size = 1073741824"
mysql -u root -e "set global innodb_flush_log_at_trx_commit = 2"

# For self-installed Drupal we're done.
if [ "$DRUPAL_MAJOR" = "none" ]
then
  clear
  printf "It's up to you! Spin up your custom Drupal instance using Composer and Drush. Example:\n\ncomposer create-project <template> somedir\ncd somedir\ncomposer require drush/drush\ndrush si\ndrush serve 0.0.0.0:8888\n"
  exit 0
fi

# Create a Drupal directory, Composer will do it to late for the second terminal task
mkdir drupal

# Create a Drupal installation using the latest stable release
composer create-project drupal/recommended-project:^${DRUPAL_MAJOR:-9} drupal

# Add Drush and a Drush base uri
cd drupal
mkdir config config/sync drush
composer require drush/drush

# Install the site
# drush-launcher is abandoned, now all use traditional path syntax to invoke drush
vendor/bin/drush si -y --site-name="Drupal ${DRUPAL_MAJOR} on Gitpod" --account-pass=admin

# Add some tweaks to settings.php
cd ./web/sites/default
chmod 0644 settings.php
printf "\$settings['trusted_host_patterns'] = [ '.*' ];\n" >> settings.php
printf "\$settings['config_sync_directory'] = '../config/sync';\n" >> settings.php
chmod 0444 settings.php

# Run cron to get rid of annoying message on status page
cd ${GITPOD_REPO_ROOT}/drupal
vendor/bin/drush cron

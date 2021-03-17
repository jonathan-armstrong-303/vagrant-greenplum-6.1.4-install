#!/bin/bash

# assign password -- needs to be the same throughout the process of course
  gpadmin_password="r0xs0xb0x"

# Source in $GPHOME, et al -- which '
  source /usr/local/greenplum-db/greenplum_path.sh

# activities to facilitate passwordless ssh.
# make ssh directory and apply right permissions.  Very important!

  cd /home/gpadmin
  mkdir ~/.ssh
  chmod 700  ~/.ssh
 
# Generate ssh key
/usr/bin/expect<<EOF
  spawn ssh-keygen 
  expect "Enter file in which to save the key (/root/.ssh/id_rsa): "
  send  "\r"
  expect "Enter passphrase (empty for no passphrase): "
  send  "\r"
  expect "Enter same passphrase again: "
  send  "\r"
  expect
EOF

# apply right permissions to recently created keys.
  chmod 600 ~/.ssh/id_rsa
  chmod 644 ~/.ssh/id_rsa.pub

# Apply permissions below.  Superfluous?  Yes. Not all these files are generated, but permissions
# included for posterity/breadcrumbs since the author can never remember them

  touch ~/.ssh/authorized_keys
  touch ~/.ssh/known_hosts
  chmod 644 ~/.ssh/authorized_keys
  chmod 644 ~/.ssh/known_hosts
  
#   chmod 700 ~/.ssh
#   chmod 600 ~/.ssh/id_rsa
#   chmod 644 ~/.ssh/id_rsa.pub
#   chmod 644 ~/.ssh/authorized_keys
#   chmod 644 ~/.ssh/known_hosts
#   restorecon -R ~/.ssh

# copy over id_rsa.pub ssh key to standby / segment servers

# yeah, I know this is an egregious violation of DRY right here, but was having some issues
# wrapping the expect script in a for loop. 
gpserver="smdw"
  /usr/bin/expect<<EOF
  spawn ssh-copy-id ${gpserver}
  expect "Are you sure you want to continue connecting (yes/no)? "
  send "yes\r"
  expect "gpadmin@${gpserver}'s password: "
  send  "${gpadmin_password}\r"
  expect
EOF

gpserver="sdw1"
  /usr/bin/expect<<EOF
  spawn ssh-copy-id ${gpserver}
  expect "Are you sure you want to continue connecting (yes/no)? "
  send "yes\r"
  expect "gpadmin@${gpserver}'s password: "
  send  "${gpadmin_password}\r"
  expect
EOF

gpserver="sdw2"
  /usr/bin/expect<<EOF
  spawn ssh-copy-id ${gpserver}
  expect "Are you sure you want to continue connecting (yes/no)? "
  send "yes\r"
  expect "gpadmin@${gpserver}'s password: "
  send  "${gpadmin_password}\r"
  expect
EOF

# Create data directories master, standby master, and segment servers
# create master data directory 

  sudo mkdir -p /data/master
  sudo chown gpadmin:gpadmin /data/master

# create same on standby (smdw) server

  gpssh -h smdw -e 'sudo mkdir -p /data/master'
  gpssh -h smdw -e 'sudo chown gpadmin:gpadmin /data/master'

# create data storage areas on segment hosts

  cd ~
  echo "sdw1" > hostfile_gpssh_segonly
  echo "sdw2" >> hostfile_gpssh_segonly

  source /usr/local/greenplum-db/greenplum_path.sh
  gpssh -f hostfile_gpssh_segonly -e 'sudo mkdir -p /data/primary'
  gpssh -f hostfile_gpssh_segonly -e 'sudo mkdir -p /data/mirror'
  gpssh -f hostfile_gpssh_segonly -e 'sudo chown -R gpadmin /data/*'

# now create hostfile_exkeys file and run gpssh-exkeys, which allows n-n passwordless ssh for gpadmin user
# (i.e., allows each server to ssh with any other server)

  cd /home/gpadmin
  echo "mdw" > ~/hostfile_exkeys
  echo "smdw" >> ~/hostfile_exkeys
  echo "sdw1" >> ~/hostfile_exkeys
  echo "sdw2" >> ~/hostfile_exkeys

  gpssh-exkeys -f hostfile_exkeys
  wait


# Run the final verification.  You should see the ls -l output from the four servers
# (mdw, smdw, sdw1, and sdw2) that all have the requisite $GPHOME directories accessible
# by passwordless ssh.

  echo "***********************************************************"
  echo "* You should see the ls -l output for all four servers    *"
  echo "* (mdw, smdw, sdw1, sdw2) below  which is indicative of   *"
  echo "* both successful Greenplum install and passwordless ssh  *"
  echo "***********************************************************"

  gpssh -f hostfile_exkeys -e 'ls -l /usr/local/greenplum-db-6.14.0'
  wait

  echo "***********************************************************"
  echo "* Now run the performance check script.  Here, we just    *"
  echo "* run the utility for segment servers only.  You just     *"
  echo "* shouldn't see anything egregious like full disk, etc.   *"
  echo "* For some reason, this gives a "No space left on device" *"
  echo "* when executed from gpcheckperf, but the "dd" command    *"
  echo "* issued by itself works as expected.  YMMV, but it does  *"
  echo "* seem to be working as expected in any case.             *"
  echo "***********************************************************"

  cd /home/gpadmin
  echo "sdw1" > ~/hostfile_gpcheckperf
  echo "sdw2" >> ~/hostfile_gpcheckperf

  gpcheckperf -f hostfile_gpcheckperf -r dsn -D -d /data/primary -d  /data/mirror

# Now, [finally!] we get to actually instantiating the Greenplum database system.
# Greenplum does not, AFAICT, explicitly state to create a "gpconfigs" configuration
# directory, but then states to copy the template here.  So, I'm not rocking the boat.

# In the interest of brevity, we will preserve the original dummy template as 
# "gpinitsystem_config_orig" with the comments on parameters intact in ~/gpconfigs
# but create a stripped-down file containing the relevant parameters only for our exercise.

# NOTE: I found Greenplum's explanation of the DATA_DIRECTORY and MIRROR_DATA_DIRECTORY
# configurations equal parts lacking and confusing.  I'm not sure what the optimal 
# configuration is, so have left each host with one primary and one mirror segments
  mkdir -p /home/gpadmin/gpconfigs  
  
  echo "sdw1" > /home/gpadmin/gpconfigs/hostfile_gpinitsystem
  echo "sdw2" >> /home/gpadmin/gpconfigs/hostfile_gpinitsystem

  cp $GPHOME/docs/cli_help/gpconfigs/gpinitsystem_config /home/gpadmin/gpconfigs/gpinitsystem_config_orig
  
  echo 'ARRAY_NAME="Greenplum Vagrant Cluster"' > /home/gpadmin/gpconfigs/gpinitsystem_config
  echo 'SEG_PREFIX=gpseg' >> /home/gpadmin/gpconfigs/gpinitsystem_config
  echo 'PORT_BASE=6000 ' >> /home/gpadmin/gpconfigs/gpinitsystem_config
  echo 'declare -a DATA_DIRECTORY=(/data/primary)' >> /home/gpadmin/gpconfigs/gpinitsystem_config
  echo 'MASTER_HOSTNAME=mdw ' >> /home/gpadmin/gpconfigs/gpinitsystem_config
  echo 'MASTER_DIRECTORY=/data/master ' >> /home/gpadmin/gpconfigs/gpinitsystem_config
  echo 'MASTER_PORT=5432 ' >> /home/gpadmin/gpconfigs/gpinitsystem_config
  echo 'TRUSTED SHELL=ssh' >> /home/gpadmin/gpconfigs/gpinitsystem_config
  echo 'CHECK_POINT_SEGMENTS=8' >> /home/gpadmin/gpconfigs/gpinitsystem_config
  echo 'ENCODING=UNICODE' >> /home/gpadmin/gpconfigs/gpinitsystem_config
  echo 'MIRROR_PORT_BASE=7000' >> /home/gpadmin/gpconfigs/gpinitsystem_config
  echo 'declare -a MIRROR_DATA_DIRECTORY=(/data/mirror)' >> /home/gpadmin/gpconfigs/gpinitsystem_config

# Wait for "Continue with Greenplum creation Yy|Nn (default=N):" prompt -- followed by "> "
# on the subsequent line 
/usr/bin/expect<<EOF
  set timeout 60
  spawn gpinitsystem -c /home/gpadmin/gpconfigs/gpinitsystem_config -h /home/gpadmin/gpconfigs/hostfile_gpinitsystem
  expect "> "
  send  "Y\r"
  expect
EOF

# Now set up MASTER_DATA_DIRECTORY 
  echo "export MASTER_DATA_DIRECTORY=/data/master/gpseg-1" >> /home/gpadmin/.bashrc
  echo "export PGPORT=5432" >> /home/gpadmin/.bashrc
  echo "export PGUSER=gpadmin" >> /home/gpadmin/.bashrc
  echo "export PGDATABASE=default_login_database_name" >> /home/gpadmin/.bashrc

# copy .bashrc over to standby master
  scp .bashrc smdw:`pwd`

# To show, potentially change, and restart gpdb after changing timezone.
# The author skipped this activity since UTC is default as well as desired timezone
# gpconfig -s TimeZone
# gpconfig -c TimeZone -v 'US/Pacific'

# restart gpdb for good measure and to source in MASTER_DATA_DIRECTORY path
  . ~/.bashrc
  gpstop -ra

# Now you're finally able to start using Greenplum!  The example two commands create
# a test database and connect:
# createdb demo
# psql demo

# To restart DB on subsequent halt/up/reloads of Vagrant, issue "gpstart" command
 

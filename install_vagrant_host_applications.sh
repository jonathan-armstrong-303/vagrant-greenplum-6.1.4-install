###################################################################################################
# necessary/handy Vagrant plugins not available as standard install
# If you have already installed Vagrant, skip to the next section.
###################################################################################################

# Update all packages and install Oracle Virtualbox
sudo apt update
sudo apt install virtualbox

# Visit Vagrant download page at https://www.vagrantup.com/downloads.html
# Download latest Vagrant version [2.2.14 as of time of writing], unzip, and install

cd ~/Downloads
unzip ./vagrant_2.2.14_linux_amd64.zip
sudo apt install vagrant

# Check status of Vagrant install. I got "2.2.6" as output even though I supposedly installed 2.2.14

vagrant --version

# Create a sample directory for Vagrant boxes

mkdir -p ~/vagrant # you will place the "Vagrantfile" file here.

cd ~/vagrant

# Now install plugins which are necessary for the subsequent Greenplum install.
vagrant plugin install vagrant-scp
vagrant plugin install vagrant-hostsupdater
vagrant plugin install vagrant-disksize
vagrant plugin install vagrant_reboot_linux

###################################################################################################
# Download the Greenplum install binary
# Technically, you don't need to do this here as it's automated in the script install -- but I've
# had occasional issues where the gpdb binary downloads painfully slowly so it's good to have it on
# hand in case for posterity you need to do a quick rebuild and are having issues downloading 
###################################################################################################
curl -L https://github.com/greenplum-db/gpdb/releases/download/6.14.0/open-source-greenplum-db-6.14.0-rhel7-x86_64.rpm -o open-source-greenplum-db-6.14.0-rhel7-x86_64.rpm

#copy Greenplum binary to guest [if needed]
# vagrant scp open-source-greenplum-db-6.14.0-rhel7-x86_64.rpm :open-source-greenplum-db-6.14.0-rhel7-x86_64.rpm

###################################################################################################
# After Install
###################################################################################################
# Copy over the final "gpadmin" install script.

scp setup_master_gpadmin_ssh.sh gpadmin@mdw:/home/gpadmin

# Note: if you've done any rework, you might get the hyperbolic 
# "WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!" warning.  To remove,
# To remove, clean up the known hosts file appropriately.  
# (On my little local Ubuntu setup here, this is facilitated by just 
# "rm ~/.ssh"; this might be too draconian for your own environment though,
# so proceed with caution.

vagrant ssh mdw
sudo su gpadmin
cd /home/gpadmin
chmod +x ./setup_master_gpadmin_ssh.sh
./setup_master_gpadmin_ssh.sh



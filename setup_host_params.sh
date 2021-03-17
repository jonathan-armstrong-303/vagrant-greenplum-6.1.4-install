# Whatever you want the gpadmin password to be.  It just has to fit some basic
# security requirements (e.g., can't be "gpadmin", etc)
gpadmin_password="r0xs0xb0x"

# Run this all as root

  sudo su -

# Get rid of some of the author's common bash shell default annoyances

echo "HISTFILESIZE=2000" >> ~/.bashrc
echo "HISTFILE=2000" >> ~/.bashrc
echo "set -o vi" >> ~/.bashrc

# Set up some useful aliases [note user is root -- we will set up for gpadmin later]
echo "alias mdw='ssh root@192.168.0.200'" >> /root/.bashrc
echo "alias smdw='ssh root@192.168.0.201'" >> /root/.bashrc
echo "alias sdw1='ssh root@192.168.0.202'" >> /root/.bashrc
echo "alias sdw2='ssh root@192.168.0.203'" >> /root/.bashrc

# Setup /etc/hosts for inter cluster communication
echo "127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4" > /etc/hosts
echo "::1         localhost localhost.localdomain localhost6 localhost6.localdomain6" >> /etc/hosts
echo "192.168.0.200     mdw        # master host" >> /etc/hosts
echo "192.168.0.201     smdw      # standby master host" >> /etc/hosts
echo "192.168.0.202     sdw1       # segment one host" >> /etc/hosts
echo "192.168.0.203     sdw2      # segment two host" >> /etc/hosts

# Assign requisite system parameters.
# calculcated sysctl  parameter formulas derived per formulas 
# https://docs.greenplum.org/6-10/install_guide/prep_os.html#topic23

echo "adjusting /etc/sysctl.conf system control parameters"
echo "kernel.shmall=`echo $(expr $(getconf _PHYS_PAGES) / 2)`" > /etc/sysctl.conf
echo "kernel.shmmax=`echo $(expr $(getconf _PHYS_PAGES) / 2 \* $(getconf PAGE_SIZE))`" >> /etc/sysctl.conf
echo "kernel.shmmni = 4096 " >> /etc/sysctl.conf
echo "kernel.sem = 500 2048000 200 4096" >> /etc/sysctl.conf
echo "kernel.sysrq = 1" >> /etc/sysctl.conf
echo "kernel.core_uses_pid = 1" >> /etc/sysctl.conf
echo "kernel.msgmnb = 65536" >> /etc/sysctl.conf
echo "kernel.msgmax = 65536" >> /etc/sysctl.conf
echo "kernel.msgmni = 2048" >> /etc/sysctl.conf
echo "net.ipv4.tcp_syncookies = 1" >> /etc/sysctl.conf
echo "net.ipv4.conf.default.accept_source_route = 0" >> /etc/sysctl.conf
echo "net.ipv4.tcp_max_syn_backlog = 4096" >> /etc/sysctl.conf
echo "net.ipv4.conf.all.arp_filter = 1" >> /etc/sysctl.conf
echo "net.core.netdev_max_backlog = 10000" >> /etc/sysctl.conf
echo "net.core.rmem_max = 2097152" >> /etc/sysctl.conf
echo "net.core.wmem_max = 2097152" >> /etc/sysctl.conf
echo "vm.swappiness = 10" >> /etc/sysctl.conf
echo "vm.zone_reclaim_mode = 0" >> /etc/sysctl.conf
echo "vm.dirty_expire_centisecs = 500" >> /etc/sysctl.conf
echo "vm.dirty_writeback_centisecs = 100" >> /etc/sysctl.conf
echo "vm.overcommit_memory = 2" >> /etc/sysctl.conf

memtotal=`awk '/MemTotal/ { printf "%.3f \n", $2/1024/1024 }' /proc/meminfo`

# Note: these next two settings are apropos for current Vagrant config
# on the author's home cluster [i.e., <= 64 GB memory]

if (( $(echo "${memtotal} <= 63" | bc -l) )); then
  echo "vm.dirty_background_ratio = 3" >> /etc/sysctl.conf
  echo "vm.dirty_ratio = 10" >> /etc/sysctl.conf
fi

# These settings are used for larger [64+ GB] memory machines
if (( $(echo "${memtotal} > 63" | bc -l) )); then
  echo "vm.dirty_background_ratio = 0" >> /etc/sysctl.conf
  echo "vm.dirty_ratio = 0" >> /etc/sysctl.conf
  echo "vm.dirty_background_bytes = 1610612736 # 1.5GB" >> /etc/sysctl.conf
  echo "vm.dirty_bytes = 4294967296 # 4GB" >> /etc/sysctl.conf
fi

# check max user processes. Per GP documentation this value should be 131072, 
# but not necessary but not necessary for smaller test cluster here -- 
# hence why I'm not bothering to do an line parameter /home/gpadminnt

maxuserprocesses=`ulimit -u`
if (( $(echo "${maxuserprocesses} != 131072" | bc -l) )); then
  echo "Max user processes should be 131072 -- current value is " ${maxuserprocesses};
else 
  echo "Max user processes is correct value per current GPDB6.14 documentation (131072)"
fi

# Disable transparent huge pages (THP's)
echo "Disabling transparent huge pages"
grubby --update-kernel=ALL --args="transparent_hugepage=never"

# Disable IPC object removal
echo "Disabling IPC object removal"
echo "RemoveIPC=no" >> /etc/systemd/logind.conf
service systemd-logind restart

# configuring ssh sessions/startup parameters
echo "MaxStartups 10:30:200" >> /etc/ssh/sshd_config
echo "MaxSessions 200" >> /etc/ssh/sshd_config

# All of these SHOULD be set to the working values as defaults, but check/replace as needed anyway.
# For whatever reason, I struggled a lot with getting passwordless ssh running on this cluster 
# (typically a fairly trivial task).
# Will reset these values back to more security-friendly configuration near install completion.
# Default values in /etc/ssh/sshd_config out of the box should be:
#   PasswordAuthentication no
#   ChallengeResponseAuthentication no
#   UsePAM yes

   sed -ie '/PasswordAuthentication no/d' /etc/ssh/sshd_config
   sed -ie 's/^#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

   sed -ie '/ChallengeResponseAuthentication no/d' /etc/ssh/sshd_config
   sed -ie 's/^#ChallengeResponseAuthentication yes/ChallengeResponseAuthentication yes/' /etc/ssh/sshd_config

   sed -ie 's/^UsePAM yes/UsePAM no/' /etc/ssh/sshd_config
   sed -ie '/UsePAM yes/d' /etc/ssh/sshd_config

# restart sshd and stop firewalld
   systemctl restart sshd.service
   systemctl stop firewalld.service
   systemctl disable firewalld.service

# Ensure there are no iptables rules.
   echo "iptables output -- you shouldn't see any rules here..."
   iptables -L -v

# Set up NTP time clocks.
# set primary (mdw) host NTP time server preference to 3.centos.pool.ntp.org and 
# comment out the preceding instances of this server.
# for smdw, set time preference to primary (mdw) and secondary to NTP server 3.centos.pool.ntp.org
# for all segment servers (sdw1/sdw2) set primary/mdw to preferred NTP time and smdw to secondary
# see https://gpdb.docs.pivotal.io/6-14/install_guide/prep_os.html#topic_qst_s5t_wy

gp_hostname=`hostname`

if [ ${gp_hostname} == "mdw" ];
  then sed -i 's/server 0.centos.pool.ntp.org/#server 0.centos.pool.ntp.org/g' /etc/ntp.conf;
       sed -i 's/server 1.centos.pool.ntp.org/#server 0.centos.pool.ntp.org/g' /etc/ntp.conf;
       sed -i 's/server 2.centos.pool.ntp.org/#server 0.centos.pool.ntp.org/g' /etc/ntp.conf;
elif [ ${gp_hostname} == "smdw" ];
    then sed -i 's/server 0.centos.pool.ntp.org/#server 0.centos.pool.ntp.org/g' /etc/ntp.conf;
       sed -i 's/server 1.centos.pool.ntp.org/#server 0.centos.pool.ntp.org/g' /etc/ntp.conf;
       sed -i 's/server 2.centos.pool.ntp.org/#server 0.centos.pool.ntp.org/g' /etc/ntp.conf;
       sed -i 's/server 3.centos.pool.ntp.org/#server 0.centos.pool.ntp.org/g' /etc/ntp.conf;
       echo "server mdw prefer" >> /etc/ntp.conf;
       echo "server 3.centos.pool.ntp.org" >> /etc/ntp.conf;
else
       sed -i 's/server 0.centos.pool.ntp.org/#server 0.centos.pool.ntp.org/g' /etc/ntp.conf;
       sed -i 's/server 1.centos.pool.ntp.org/#server 0.centos.pool.ntp.org/g' /etc/ntp.conf;
       sed -i 's/server 2.centos.pool.ntp.org/#server 0.centos.pool.ntp.org/g' /etc/ntp.conf;
       sed -i 's/server 3.centos.pool.ntp.org/#server 0.centos.pool.ntp.org/g' /etc/ntp.conf;
       echo "server mdw prefer" >> /etc/ntp.conf;
       echo "server smdw" >> /etc/ntp.conf;
fi

# Create gpadmin user and group 
# Note -- take out the hash before the "EOF" -- only added because the << messed up vi display colors
   groupadd gpadmin
   useradd gpadmin -r -m -g gpadmin
   /usr/bin/expect <<EOF
   spawn passwd gpadmin
   expect "New password: "
   send "${gpadmin_password}\r"
   expect "Retype new password: "
   send  "${gpadmin_password}\r"
   expect "passwd: all authentication tokens updated successfully."
EOF

# Allow gpadmin sudo privileges and get rid of password prompt annoyance
   #actual GP documentation states to use "wheel" line below... ymmv
   #%wheel        ALL=(ALL)       NOPASSWD: ALL
   echo "gpadmin ALL=(ALL) ALL" >> /etc/sudoers
   echo "gpadmin ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Install gpdb in the gpadmin home directory as root.
# I found this little nuance to be extremely confusing.  Until the install, there is no bona-fide
# $GPHOME directory; if the software is installed as root in root's home, or as gpadmin in gpadmin's
# $HOME, it will botch all subsequent activity.
# So, to reiterate: cd to the gpadmin home, but _install_ as root

# Get rid of some default bash annoyances [for gpadmin this time -- we've already done this for root]
  echo "HISTFILESIZE=2000" >> /home/gpadmin/.bashrc
  echo "HISTFILE=2000" >> /home/gpadmin/.bashrc
  echo "set -o vi" >> /home/gpadmin/.bashrc

# Set up some useful aliases
  echo "alias mdw='ssh gpadmin@192.168.0.200'" >> /home/gpadmin/.bashrc
  echo "alias smdw='ssh gpadmin@192.168.0.201'" >> /home/gpadmin/.bashrc
  echo "alias sdw1='ssh gpadmin@192.168.0.202'" >> /home/gpadmin/.bashrc
  echo "alias sdw2='ssh gpadmin@192.168.0.203'" >> /home/gpadmin/.bashrc

# Source in gpadmin environment upon boot
  echo "source /usr/local/greenplum-db/greenplum_path.sh" >> /home/gpadmin/.bashrc

   cd /home/gpadmin
   curl -L https://github.com/greenplum-db/gpdb/releases/download/6.14.0/open-source-greenplum-db-6.14.0-rhel7-x86_64.rpm -o open-source-greenplum-db-6.14.0-rhel7-x86_64.rpm
   yum install open-source-greenplum-db-6.14.0-rhel7-x86_64.rpm -y

# Change ownership of gpadmin directories to gpadmin user
   sudo chown -R gpadmin:gpadmin /usr/local/greenplum*
   sudo chgrp -R gpadmin /usr/local/greenplum*

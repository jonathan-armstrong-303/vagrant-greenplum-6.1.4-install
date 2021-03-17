# reset the sshd_configs to be more security conscious after getting passwordless ssh working.

   sudo su -

   sed -ie 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
   sed -ie 's/ChallengeResponseAuthentication yes/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
   sed -ie 's/UsePAM no/UsePAM yes/' /etc/ssh/sshd_config
   echo "UsePAM yes" >> /etc/ssh/sshd_config

   systemctl restart sshd.service

   egrep "^PasswordAuthentication|^ChallengeResponseAuthentication|^UsePAM" /etc/ssh/sshd_config

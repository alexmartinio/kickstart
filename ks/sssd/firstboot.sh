#!/bin/bash

/usr/bin/curl --silent "http://repos.redarrow.co.uk/ks/sssd/join-domain.py" | /usr/bin/python

/bin/cat /etc/crontab | /bin/grep -v firstboot > /etc/crontab.tmp
/bin/rm -f /etc/crontab
/bin/mv /etc/crontab.tmp /etc/crontab
/usr/sbin/restorecon -Fv /etc/crontab
/bin/rm -f $0

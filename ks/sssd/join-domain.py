#!/usr/bin/python

import os
import re
import socket
import stat
import subprocess
import sys
import tempfile
import time
 
now = time.strftime("%c")
## Display current date and time from now variable 
print ("Script started:  %s"  % now )
time.sleep(5)

#
# chroot if kickstart
#
sysroot = '/mnt/sysimage'
if os.path.exists(sysroot):
    os.chroot(sysroot)
    os.chdir("/")


#
# realmd setup
#

domain = "ad.alexmartin.io"
ou = "OU=Linux,OU=Servers,OU=Resources,DC=AD,DC=ad,DC=alexmartin,DC=io"
principal = "HOST/LinuxADJoin@AD.ALEXMARTIN.IO"
keytaburl = "http://repos.alexmartio.co.uk/ks/sssd/domainjoin.keytab"
fqdn = socket.getfqdn().lower()
hostspn = "host/{}@AD.ALEXMARTIN.IO".format(fqdn)
keytab = os.path.join(tempfile.mkdtemp(), "domainjoin.keytab")

print('')
print('Attempting to resolve {}...'.format(domain)),

if ( socket.gethostbyname(domain) ):
    print('Resolved to {}.'.format(socket.gethostbyname(domain)))
    proc = subprocess.call(["curl", "--silent", "-o", keytab, keytaburl])
    proc = subprocess.call(["kdestroy", ])
    print('')
    if os.path.exists(keytab):
        proc = subprocess.call(["kinit", principal, "-k", "-t", keytab])
        print('')
        proc = subprocess.call(["klist", ]) 
        print('')
        proc = subprocess.call(["realm", "join", "--computer-ou", ou, "--user-principal", hostspn, "--verbose", ])
        #print(proc) # result
        proc = subprocess.call(["kdestroy", ])

    # Tidy up - remove keyfile for security (just in case)
    if os.path.exists(keytab):
        os.remove(keytab)
        os.rmdir(os.path.dirname(keytab))

else:
    print('Unable to resolve, exiting..')
    sys.exit()


#
# Update nsswitch.conf
#

filepath = '/etc/nsswitch.conf'

appendstring = """
# Alex - 2017-06-23
# SSSD AD Sudo Powers
sudoers:    files sss
"""

err_occur = []                                                  # The list where we will store results.
pattern = re.compile("^sudoers", re.IGNORECASE)                 # Compile a case-insensitive regex pattern.
try:                                                            # Try to:
    with open (filepath, 'r+') as in_file:                      # open file for reading text.
        for linenum, line in enumerate(in_file):                # Keep track of line numbers.
            if pattern.search(line) != None:                    # If substring search finds a match,
                err_occur.append((linenum, line.rstrip('\n')))  # strip linebreaks, store line and line number in list as tuple.
                for linenum, line in err_occur:                 # Iterate over the list of tuples, and
                    #print("Line ", linenum, ": ", line, sep='') # print results as "Line [linenum]: [line]". Python 3
                    print('\nWARNING: sudoers line already present in: {}...'.format(filepath))
        if not err_occur:
            print('Updating: {}...'.format(filepath))           # If search list is empty
            in_file.seek(0, os.SEEK_END)                        # Go to the end of the file
            in_file.write(appendstring)                         # Append the string

except FileNotFoundError:                                       # If log file not found,
    print("Log file not found.")                                # print an error message.


#
# SSSD config
#
filepath = '/etc/sssd/conf.d/01_sssd.conf'
contents = """
# Alex - 2017-06-23
# sssd local config

[sssd]
services = nss, pam, sudo

[domain/ad.alexmartin.io]
use_fully_qualified_names = False
fallback_homedir = /home/%u
ldap_sudo_search_base = OU=Sudoers,OU=Systems,OU=Groups,OU=Resources,DC=AD,DC=ad,DC=alexmartin,DC=io
ad_site = Romsey
"""

if not os.path.exists(os.path.dirname(filepath)):
    try:
        os.makedirs(os.path.dirname(filepath))
    except OSError as exc: # Guard against race condition
        if exc.errno != errno.EEXIST:
            raise

print(os.getcwd())
print(os.listdir('/mnt'))
print(os.listdir('/etc/sssd'))


if not os.path.exists(filepath):                                # Don't overwrite if file already exists
    with open(filepath, 'a+') as f:
        print('Updating: {}...'.format(filepath))
        f.write(contents)
else:
    print('WARNING: File already exists: {}...'.format(filepath))

os.chmod(filepath, stat.S_IRUSR | stat.S_IWUSR)                         # Sets permissions 
proc = subprocess.call(["/usr/sbin/restorecon", '-F', '-v', filepath])  # Reset file context

#
# krb5.config file
#


print('')
print('')

# Restart SSSD
proc = subprocess.call(["/usr/bin/systemctl", 'restart', 'sssd.service'])

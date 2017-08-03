# Auto Copy UCS from another machine
# V1.0 By ValentineG 2017-07-16

# We need to use SCP so first create an PKI trust, Execute "ssh-keygen" on recieving f5 without paraphrase,
# save it to /root/.ssh/f5AutoUCS and copy public key(/root/.ssh/f5AutoUCS.pub) to the F5 from which you wish to pull the config
# use the comand : ssh <F5 USER>@<F5 HOSTNAME> 'cat /root/.ssh/f5AutoUCS.pub' >> ~/.ssh/authorized_keys

echo `date +"%B %d %H:%M:%S"` Starting f5 UCS config sync >> /var/tmp/scripts/autoUCS.log

_hostname=`uname -n`
_now=`date +"%d_%m_%Y"`


# enter the username here:
_user='root'

# enter the MGMT IPs of local and remote F5s
_remoteF5='x.x.x.x'

_localF5="$(grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' <<< `tmsh list sys management-ip` )"

# UCS Location
_ucsLoc='/var/tmp/scripts'


#Create the UCS on remote device and download it to local device via SCP
_sshOut=$(ssh -i /root/.ssh/f5backup $_user@$_remoteF5 << EOF
 tmsh save sys ucs $_ucsLoc/f5AutoUCS-$_now
 scp -i /root/.ssh/f5backup $_ucsLoc/f5AutoUCS-$_now.ucs $_user@$_localF5:$_ucsLoc/f5AutoUCS-$_now.ucs
 rm -rf $_ucsLoc/f5AutoUCS-$_now.ucs
EOF)

if [ $? -eq 0 ] ; then
        echo `date +"%B %d %H:%M:%S"` successfully connected to remote device and got the UCS! >> /var/tmp/scripts/autoUCS.log
else
        echo `date +"%B %d %H:%M:%S"` didnt manage to connect to remote device OR get the UCS! >> /var/tmp/scripts/autoUCS.log
        exit 1
fi

echo $_sshOut

#extract the UCS in order to import local base config file
mkdir $_ucsLoc/UCS
mv $_ucsLoc/f5AutoUCS-$_now.ucs $_ucsLoc/UCS/
cd $_ucsLoc/UCS
gzip -dc f5AutoUCS-$_now.ucs | tar xvpf -

if [ $? -eq 0 ] ; then
        echo `date +"%B %d %H:%M:%S"` successfully extracted the UCS! >> /var/tmp/scripts/autoUCS.log
else
        echo `date +"%B %d %H:%M:%S"` didnt manage to extract the UCS! >> /var/tmp/scripts/autoUCS.log
        exit 2
fi

# remove the UCS got from remote device
rm -f f5AutoUCS-$_now.ucs

# Make desired changes to bigip.conf
ex -sc '%s/x.x.x.y/x.x.x.z/g|x' config/bigip.conf

# Import base config file to new UCS
cp /config/bigip_base.conf config/bigip_base.conf

# Compress back the configuration to a new UCS and clean the files
tar cvf - * | gzip -c > $_ucsLoc/f5AutoUCS-$_now.ucs

if [ $? -eq 0 ] ; then
        echo `date +"%B %d %H:%M:%S"` successfully compressed the UCS! >> /var/tmp/scripts/autoUCS.log
else
        echo `date +"%B %d %H:%M:%S"` didnt manage to compress the UCS! >> /var/tmp/scripts/autoUCS.log
        exit 3
fi


rm -rf $_ucsLoc/UCS

tmsh load sys ucs $_ucsLoc/f5AutoUCS-$_now.ucs no-license no-platform-check

if [ $? -eq 0 ] ; then
        echo `date +"%B %d %H:%M:%S"` successfully ran UCS load! >> /var/tmp/scripts/autoUCS.log
else
        echo `date +"%B %d %H:%M:%S"` didnt manage run UCS load! >> /var/tmp/scripts/autoUCS.log
        exit 3
fi

tmsh modify sys global-settings hostname temp.temp
tmsh modify sys global-settings hostname $_hostname

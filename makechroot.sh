#!/bin/bash
# This script can be used to create simple chroot environment
# The script:
#   - asks for user and password
#   - create chroot environment with commands
#   - adjust sshd_config


if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit
fi

SSHD=/etc/ssh/sshd_config
ROOT="/var/chroot"
CMD=$(which ls locale cat echo bash tar file man vi vim cp mv rm id mkdir scp mysql grep sed less ssh git)


read -p "Enter chroot user: " USER
CHROOT="$ROOT/$USER"
if [ -d "$CHROOT" ]; then
    echo "User already exists."
    read -p "Continue? [y/N]: " YN
    if [ "$YN" != "y" ]; then
        echo "Aborted."
        exit
    fi
else
    #create user
    useradd "$USER" -d / -s /bin/bash
    groupadd chrootjail
    usermod -a -G chrootjail "$USER"
    # disabled password logon
    #read -p "Enter chroot password: " PASSWD
    #[[ -z "$PASSWD" ]] || (echo -e "$PASSWD\n$PASSWD" | passwd "$USER")
fi
mkdir -p "$CHROOT"



# enable commands
for i in $( ldd $CMD | grep -v dynamic | cut -d " " -f 3 | sed 's/://' | sort | uniq ); do
    cp --parents "$i" "$CHROOT"
done

# ARCH amd64
if [ -f /lib64/ld-linux-x86-64.so.2 ]; then
    cp --parents /lib64/ld-linux-x86-64.so.2 "$CHROOT"
fi

# ARCH i386
if [ -f  /lib/ld-linux.so.2 ]; then
    cp --parents /lib/ld-linux.so.2 "$CHROOT"
fi



#files for dns/hosts resolving
for F in libnss_files.so.2 libnss_dns.so.2; do
    CP=$(dirname "$(locate $F)")
    mkdir -p "$CHROOT/$CP/"
    cp "$CP"/"$F" "$CHROOT/$CP/"
done
mkdir -p "$CHROOT"/etc
cp /etc/resolv.conf "$CHROOT/etc/"



#create virtual dirs and bind /dev
for D in dev sys run proc; do mkdir -p "$CHROOT"/$D ; done
mount -o bind /dev "$CHROOT"/dev



#create tmp dir
[[ -d "$CHROOT"/tmp ]] || install -d -o "$USER" -g "$USER" "$CHROOT"/tmp



#passwd
egrep "$USER" /etc/passwd > "$CHROOT"/etc/passwd
egrep "$USER" /etc/group > "$CHROOT"/etc/group



#wwwroot
[[ -d "$CHROOT"/wwwroot ]] || install -d -o "$USER" -g "$USER" "$CHROOT"/wwwroot



#create .ssh
mkdir -p "$ROOT"/.ssh
touch "$ROOT"/.ssh/authorized_keys_"$USER"



#create .bashrc
cat << EOF > $CHROOT/.bashrc
export HISTTIMEFORMAT="| %d.%m.%y %T =>  "
shopt -s histappend
PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
EOF



#create .bash_profile
echo 'source "/.bashrc"' > "$CHROOT"/.bash_profile



#create .bash_history
[[ -f "$CHROOT"/.bash_history ]] || install -o "$USER" -g "$USER" -m 644 /dev/null "$CHROOT"/.bash_history


# sshd stuff
sed  -i 's;^Subsystem sftp /usr/lib/openssh/sftp-server;#Subsystem sftp /usr/lib/openssh/sftp-server\nSubsystem sftp internal-sftp;g' "$SSHD"

if ! egrep -q "^Match group chrootjail" "$SSHD"; then
    echo >> "$SSHD"
    echo "Match group chrootjail" >> "$SSHD"
    echo "      PubkeyAuthentication yes" >> "$SSHD"
    echo "      ChrootDirectory $ROOT/%u" >> "$SSHD"
    echo "      AuthorizedKeysFile $ROOT/.ssh/authorized_keys_%u" >> "$SSHD"
    sshd -t && service ssh restart || echo "Error in $SSHD"
fi



echo -e "\n\nChrootDirectory $CHROOT"
echo "AuthorizedKeysFile $ROOT/.ssh/authorized_keys_$USER"
echo -e "\n\nChroot jail is ready. To access it execute: chroot $CHROOT"
echo -e "\n\nbindfs example:"
echo "   bindfs -g www-data -m $USER --create-for-user=www-data --create-for-group=www-data --create-with-perms=0644,a+X /var/www/www.bikecenter.be/wwwroot $CHROOT/wwwroot/"

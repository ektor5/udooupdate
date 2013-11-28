#!/bin/bash

cat <<HERE

 ################################
 #				#
 # UDOO Kernel & U-Boot Updater	#
 #				#
 ################################

HERE

# Ek5 @ 2013-10

help(){

 cat <<HELP
Usage: $0 [OPTION]...

Options:
  -r ROOT, --root=ROOT       install the modules in ROOT/lib/modules
  -m MMC,  --mmc=MMC         use the desired MMC device instead of /dev/mmcblk0
  -c CPU,  --cpu=CPU         specify the CPU type [quad, dual]

All of this commands are useful for cross-updating UDOO from your pc.
So don't touch them if you're not sure of what you are doing!

Report bugs to <info@udoo.org>.
HELP

 exit
}

error(){
 echo "Error: $1" 1>&2
 exit 1
}

ok(){
 sync
 sleep 1
 echo "done!"
}

PREFIX=""
CPU=""
UIMAGE="uImage"
MODULES="modules.tar.gz"
DUAL="u-boot-d.imx"
QUAD="u-boot-q.imx"
MMC="/dev/mmcblk0"
DMSGOUT=$(dmesg)

until [ -z $1 ] 

do
	case $1 in
	--root=*)
		PREFIX=`echo $1 | cut -d "=" -f 2`
		;;
	-r)	
		shift ; PREFIX=$1
		;; 
	--mmc=*)
		MMC=`echo $1 | cut -d "=" -f 2`
		;;
	-m)	
		shift ; MMC=$1
		;;
	--cpu=*)
		CPU=`echo $1 | cut -d "=" -f 2`
		;;
	-c)
		shift ; CPU=$1
		;;
	*)
		help
		;;
	esac
	shift
done

#Check if run as root
if [[ "$(id -u)" != "0" ]]; then
    error "You are not root. Try execute: sudo ./udooupdate.sh"
fi

#Check options
if [ ! -b $MMC ]
then
 error "$MMC isn't a regular block file" 
fi

if [ ! -d $PREFIX ]
then
 echo "Error: Prefix not valid!";
 help
fi

case $CPU in
	quad) UBOOT="$QUAD";;
	dual) UBOOT="$DUAL";;
	"") 
		DMSGOUT=$(dmesg)
	
		if [[ $DMSGOUT =~ "UDOO quad" ]] 
		then
		 UBOOT="$QUAD"
		 CPU="quad"
	
		elif [[ $DMSGOUT =~ "UDOO dual" ]]
		then
		 UBOOT="$DUAL"
		 CPU="dual"
	
		else
		 error "Can't guess the UDOO cpu (use the '-c CPU' option)"
	    	fi
	;;
	*) error "Choose between 'quad' or 'dual'"
	;;
esac

#Check files
[ -f $MODULES ] || error "modules.tar.gz not found"
[ -f $UIMAGE ] 	|| error "uImage not found"
[ -f $UBOOT ]  	|| error "$UBOOT not found"

##############
# KERNEL
##############

if [ -e $PREFIX/boot/$UIMAGE ]
then
 echo -n "Backing up the previous kernel..."
 mv $PREFIX/boot/$UIMAGE $PREFIX/boot/${UIMAGE}.bak  || error "Failed to backup the kernel"
 ok
fi

echo -n "Copying kernel image..."
cp uImage $PREFIX/boot/$UIMAGE || error "Failed to install the kernel"
ok

#############
#MODULES
#############

if [[ $DMSGOUT =~ "UDOO" ]]
then
 KERNEL_REL=`uname --kernel-release`
else
 KERNEL_REL=`tar -tzf $MODULES | sed -n "3p" | cut -d \/ -f 3`
fi

MOD_PATH="$PREFIX/lib/modules/$KERNEL_REL"

if [ -d ${MOD_PATH}_bak ] 
then  
  echo -n "Removing old backup..." ; 
  rm -r ${MOD_PATH}_bak || error "Failed to remove"  
  ok 
fi

if [ -d $MOD_PATH ]
then
  echo -n "Backing up old modules..."
  mv $MOD_PATH ${MOD_PATH}_bak || error "Failed to move"
  ok
fi


echo -n "Installing kernel modules..."

tar -xzpf $MODULES -C $PREFIX/ || error "Broken tar?"

ok

#############
#U-BOOT
#############

echo "Copying uboot for the i.Mx6 $CPU..."

dd if=$UBOOT of=$MMC bs=512 seek=2 status=noxfer || error "is $MMC correct?"

ok

echo
echo "Now you can reboot and remove update files. Enjoy!"

#echo -n "Removing update files ..."
# rm uImage u-boot.img
# rm udooupdate.sh
#sync
#sleep 2
#echo "done!"

#echo "Rebooting the board..."
#sudo reboot

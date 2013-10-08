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

Report bugs to <udoo@UDOO.org>.
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
DUAL="u-boot-dl.bin"
QUAD="u-boot-q.bin"
MMC="/dev/mmcblk0"

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


if [ ! -c $MMC ]
then
 echo "Error: $MMC isn't a regular block file" 
 MMC=""
 exit 1
fi

if [ ! -d $PREFIX ]
then
 echo "Error: Prefix not valid!";
 help
fi
exit

case $CPU in
	quad) UBOOT="$QUAD";;
	dual) UBOOT="$DUAL";;
	"") 
		DMSGOUT=$(dmesg)
	
		if [[ DMSGOUT =~ "UDOO quad" ]] 
		then
		 UBOOT="$QUAD"
		 CPU="quad"
	
		elif [[ DMSGOUT =~ "UDOO dual" ]]
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

#Check if run as root
if [[ "$(id -u)" != "0" ]]; then
    error "You are not root. Try execute: sudo ./udooupdate.sh"
fi

##############
# KERNEL
##############

if [ -e $PREFIX/boot/uImage ]
then
 echo -n "Backing up the previous kernel..."
 mv $PREFIX/boot/uImage $PREFIX/boot/uImage.bak
 ok
fi

echo -n "Copying kernel image..."
cp uImage $PREFIX/boot/uImage
ok

#############
#MODULES
#############

KERNEL_REL=`uname --kernel-release`

if [ -d $PREFIX/lib/modules/$KERNEL_REL ]
then
  echo -n "Removing old modules..."
  rm -r $PREFIX/lib/modules/$KERNEL_REL || error "Failed to remove"
  ok
fi

echo -n "Installing kernel modules..."
tar -xzpf modules.tar.gz -C $PREFIX/ 	|| error "Broken tar?"
#cp -r lib $PREFIX 			|| error "symbolic lib?"
ok

#############
#U-BOOT
#############

echo -n "Copying uboot for the i.Mx6 $CPU..."

dd if=$UBOOT of=$MMC bs=512 seek=2 skip=2 status=none || error "is $MMC correct?"

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

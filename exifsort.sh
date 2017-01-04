#!/bin/bash
#
###############################################################################
# This script is a fork of exifsort bash script by Mike Beach.
# 
# Last update (by Adam Niko Niklaus): 4-Jan-2017
#
# Photo sorting program by Mike Beach
# For usage and instructions, and to leave feedback, see
# http://mikebeach.org/?p=4729
#
# Last update: 20-May-2013
###############################################################################
#
# The following are the only settings you should need to change:
#
# TS_AS_FILENAME: This can help eliminate duplicate images during sorting.
# WARNING: Any two files with the same filename are automatically overwritten when
# this is on. FIXME: Handle filename collisions.
# TRUE: File will be renamed to the Unix timestamp and its extension.
# FALSE (any non-TRUE value): Filename is unchanged.
TS_AS_FILENAME=TRUE
#
# USE_LMDATE: If this is TRUE, images without EXIF data will have their Last Modified file
# timestamp used as a fallback. 
#Niko;) - Updated below:
#>>If FALSE, images without EXIF data are put in noexif/ for manual sorting.<<
#If FALSE, images without EXIF data are left in origin folder for manual sorting.
# WARNING: Filename collisions are NOT handled when this is off. Files are automatically
# overwritten.
# FIXME: Handle collisions when this is off.
# Valid options are "TRUE" or anything else (assumes FALSE). FIXME: Restrict to TRUE/FALSE
#
USE_LMDATE=FALSE
# Only used if USE_LMDATE is set to TRUE. If set to TRUE it will try to extract a valid date
# from file's filename. Only when date is successfuly extracted and matches file's Last Modified 
# timestamp it will continue. Otherwise it will stop and apply action defined by: NO_EXIF_ACTION
USE_LMDATE_SAFE=TRUE
#
# USE_FILE_EXT: The following option is here as a compatibility option as well as a bugfix.
# If this is set to TRUE, files are identified using FILE's magic, and the extension
# is set accordingly. If FALSE (or any other value), file extension is left as-is.
# CAUTION: If set to TRUE, extensions may be changed to values you do not expect.
# See the manual page for file(1) to understand how this works.
# NOTE: This option is only honored if TS_AS_FILENAME is TRUE.
#
USE_FILE_EXT=FALSE
#
# JPEG_TO_JPG: The following option is here for personal preference. If TRUE, this will
# cause .jpg to be used instead of .jpeg as the file extension. If FALSE (or any other
# value) .jpeg is used instead. This is only used if USE_FILE_EXT is TRUE and used.
#
JPEG_TO_JPG=FALSE
#
#
# The following is an array of filetypes that we intend to locate using find.
# Any imagemagick-supported filetype can be used, but EXIF data is only present in
# jpeg and tiff. Script will optionally use the last-modified time for sorting (see above)
# Extensions are matched case-insensitive. *.jpg is treated the same as *.JPG, etc.
# Can handle any file type; not just EXIF-enabled file types. See USE_LMDATE above.
#
FILETYPES=("*.jpg" "*.jpeg" "*.png" "*.tif" "*.tiff" "*.gif" "*.xcf" "*.avi" "*.mp4" "*.mpg" "*.mpeg" "*.mov" "*.3gp" "*.raf" "*.cr2")
#
# Optional: Prefix of new top-level directory to move sorted photos to.
# if you use MOVETO, it MUST have a trailing slash! Can be a relative pathspec, but an
# absolute pathspec is recommended.
# FIXME: Gracefully handle unavailable destinations, non-trailing slash, etc.
#
MOVETO=""
#
#
TOOL_PRESENT_EXIFTOOL=FALSE # Niko;) : Preffered
TOOL_PRESENT_IDENTIFY=FALSE
CHECKSUM_TYPES=("CRC" "MD5")
CHECKSUM_TYPE=${CHECKSUM_TYPES[0]} # Niko;) : 0 - CRC (by default), 1 - MD5
USE_LOG_FILE=TRUE
LOG_FILENAME="./exifsort.log"
NO_EXIF_ACTIONS=("NONE" "MOVE_TO_NOEXIF")
NO_EXIF_ACTION=${NO_EXIF_ACTIONS[0]} # Niko;) : 0 - none (leave as it is), 1 - move to NOEXIF folder
###############################################################################
# When set to TRUE, an image created 2017-01-13 will be placed in folder
# /2017/01/13. When set to FALSE the destination folder would be 2017-01-13
USE_TREE_FOLDER=FALSE
#
###############################################################################
# End of settings. If you feel the need to modify anything below here, please share
# your edits at the URL above so that improvements can be made to the script. Thanks!
#
#
# Assume find, grep, stat, awk, sed, tr, etc.. are already here, valid, and working.
# This may be an issue for environments which use gawk instead of awk, etc.
# Please report your environment and adjustments at the URL above.
#
###############################################################################

function_get_crc() {
	local FILENAME=$1
	CRC_CODE=`cksum "$FILENAME" | awk -F' ' '{print $1}'`
	echo "${CRC_CODE}"
}

function_get_md5() {
	local FILENAME=$1
	MD5_CODE=`md5sum "$FILENAME" | awk -F' ' '{print $1}'`
	echo "${MD5_CODE}"
}

function_remove_sum() {
	local FILENAME=$1
	#CLEAN_FILENAME=`echo $FILENAME | sed 's/\(\w*\)_CRC:.*/\1/'`
	CLEAN_FILENAME=`echo $FILENAME | sed 's/_'"$CHECKSUM_TYPE"':[0-9a-z]*//'`
	echo "${CLEAN_FILENAME}"
}

function_write_to_log() {
	if [ "$USE_LOG_FILE" == "TRUE" ] ; then
		echo "$1" >> $LOG_FILENAME
	fi
}


# Nested execution (action) call
# This is invoked when the programs calls itself with
# $1 = "doAction"
# $2 = <file to handle>
# This is NOT expected to be run by the user in this matter, but can be for single image
# sorting. Minor output issue when run in this manner. Related to find -print0 below.
#
# Are we supposed to run an action? If not, skip this entire section.
if [[ "$1" == "doAction" && "$2" != "" ]]; then
	TOOL_PRESENT_EXIFTOOL=$3
	TOOL_PRESENT_IDENTIFY=$4
	# Niko;) : Ignore files with CRC: in the name, as they are already processed by
	# this script.
	#echo ">>>>>>>>>>>>>>>>>["$(function_remove_sum "$2")"]"	
	if [[ "$2" != *"CRC:"* ]]; then
		echo ""
		# Check CRC sum. This is to avoid overwritting a file taken at the same
		# datetime or by a modified copy or if EXIF data are incorrect (etc same
		# create datetime for a set of different images - as for Moto G2).
		case "$CHECKSUM_TYPE" in
			CRC) FILE_CHECK_SUM=$(function_get_crc "$2")
				;;
			MD5) FILE_CHECK_SUM=$(function_get_md5 "$2")
				;;
		esac
		if [[ "$FILE_CHECK_SUM" != "" ]] ; then
			#echo "CRC:${FILE_CHECK_SUM}"
			# Evaluate the file extension
			if [ "$USE_FILE_EXT" == "TRUE" ]; then
				 # Get the FILE type and lowercase it for use as the extension
				 EXT=`file -b $2 | awk -F' ' '{print $1}' | tr '[:upper:]' '[:lower:]'`
				 if [[ "${EXT}" == "jpeg" && "${JPEG_TO_JPG}" == "TRUE" ]]; then 
					EXT="jpg"; 
				 fi;
			else
			 	# Lowercase and use the current extension as-is
			 	EXT=`echo $2 | awk -F. '{print $NF}' | tr '[:upper:]' '[:lower:]'`
			fi;
			# Check for EXIF and process it
			echo -n ": Checking EXIF... "
			if [ "$TOOL_PRESENT_EXIFTOOL" == "TRUE" ] ; then
				DATETIME=`exiftool -d "%Y:%m:%d %H:%M:%S" -CreateDate "$2" | awk -F' ' '{print $4" "$5}'`
			else
				if [ "$TOOL_PRESENT_IDENTIFY" == "TRUE" ] ; then
					DATETIME=`identify -verbose "$2" | grep "exif:DateTime:" | awk -F' ' '{print $2" "$3}'`
				fi;
			fi;
			# Niko;) : "2002:12:08 12:00:00" - Incorrect EXIF timestamp in same Moto G4 (mk2) JPGs
			if [[ "$DATETIME" == "" ]] || [[ "$DATETIME" == "2002:12:08 12:00:00" ]]; then
				echo "not found."
				# Niko;) : Add info to log file
				function_write_to_log "$2 : No EXIF found."

				if [[ $USE_LMDATE == "TRUE" ]]; then
					# I am deliberately not using %Y here because of the desire to display the date/time
					# to the user, though I could avoid a lot of post-processing by using it.
					echo " Using LMDATE: $DATETIME"
					DATE_FROM_FILENAME=`basename "$2" | grep -Eo '([[:digit:]]{4}-[[:digit:]]{2}-[[:digit:]]{2}|[[:digit:]]{8})' | head -1`
					if [[ ${#DATE_FROM_FILENAME} -gt "0" ]] ; then
						DATE_FROM_FILENAME=`date -d "$DATE_FROM_FILENAME" +%Y-%m-%d`
						#function_write_to_log "DATE_FROM_FILENAME: $2 ($DATE_FROM_FILENAME)"
						# I am deliberately not using %Y here because of the desire to display the date/time
						# to the user, though I could avoid a lot of post-processing by using it.
						DATETIME=`stat --printf='%y' "$2" | awk -F. '{print $1}' | sed y/-/:/`
						DATE_FROM_LMDATE=`echo "$DATETIME" | awk -F' ' '{print $1}' | sed y/:/-/`
						if [[ "$USE_LMDATE_SAFE" == "TRUE" ]] ; then
							if [[ "$DATE_FROM_LMDATE" == "$DATE_FROM_FILENAME" ]] ; then
								function_write_to_log "$2 : Creation date same as the one in filename"
							else
								function_write_to_log "$2 : SKIPPING: Creation date different than the one in filename ([$DATE_FROM_FILENAME][$DATE_FROM_LMDATE])"
								exit
							fi;
						else
							function_write_to_log "$2 : Using LMDATE: $DATETIME"
						fi;
					fi;
				else
					if [[ "$NO_EXIF_ACTION" == "MOVE_TO_NOEXIF" ]] ; then
						echo " Moving to ./noexif/"
						FILENAME_ORIG=$(basename "$2")
						FILENAME_ORIG="${FILENAME_ORIG%.*}"
						FILENAME=$FILENAME_ORIG"_"$CHECKSUM_TYPE":"$FILE_CHECK_SUM"."$EXT
						mkdir -p "${MOVETO}noexif" && mv -f "$2" "${MOVETO}noexif/${FILENAME}"
						#echo "mkdir - p ${MOVETO}noexif && mv -f ${2} ${MOVETO}noexif/${FILENAME}"
						function_write_to_log "$2 : Moved to ${MOVETO}noexif/${FILENAME}"
					fi;
					exit
				fi;
			else
			 	echo "found: $DATETIME"
			fi;
			# The previous iteration of this script had a major bug which involved handling the
			# renaming of the file when using TS_AS_FILENAME. The following sections have been
			# rewritten to handle the action correctly as well as fix previously mangled filenames.
			# FIXME: Collisions are not handled.
			#
			EDATE=`echo $DATETIME | awk -F' ' '{print $1}'`
			# Evaluate the file name
			if [ "$TS_AS_FILENAME" == "TRUE" ]; then
				# Get date and times from EXIF stamp
				ETIME=`echo $DATETIME | awk -F' ' '{print $2}'`
				# Unix Formatted DATE and TIME - For feeding to date()
				UFDATE=`echo $EDATE | sed y/:/-/`
				# Unix DateSTAMP
				UDSTAMP=`date -d "$UFDATE $ETIME" +%s`
				#FILENAME=$UDSTAMP
				# Exif Creation DateSTAMP
				EXIFDATE_FILENAME=`tr -d ":" <<<$DATETIME | sed 's/ /_/g'`

				FILENAME=$EXIFDATE_FILENAME"_UD:"$UDSTAMP"_"$CHECKSUM_TYPE":"$FILE_CHECK_SUM
				#| tr -d ":" | awk '{print $1 $2}' |

				echo " Will rename to $FILENAME.$EXT"
				MVCMD="/$FILENAME.$EXT"
			fi;
			# DIRectory NAME for the file move
			# sed issue for y command fix provided by thomas
			if [[ "$USE_TREE_FOLDER" == "TRUE" ]] ; then
				DIRNAME=`echo $EDATE | sed y-:-/-`
			else
				DIRNAME=`echo $EDATE | sed y-:-\\\--`
			fi;
			 
			echo -n " Moving to ${MOVETO}${DIRNAME}${MVCMD} ... "
			mkdir -p "${MOVETO}${DIRNAME}" && mv -f "$2" "${MOVETO}${DIRNAME}${MVCMD}"
			#echo "mkdir - p ${MOVETO}${DIRNAME} && mv -f ${2} ${MOVETO}${DIRNAME}${MVCMD}"
			echo "done."
			echo ""
			function_write_to_log "$2 : Moved to ${MOVETO}${DIRNAME}${MVCMD}"
		fi;
	else
		echo -e " <= Skipping!"
	fi;
	exit
fi;


#
###############################################################################
# Scanning (find) loop
# This is the normal loop that is run when the program is executed by the user.
# This runs find for the recursive searching, then find invokes this program with the two
# parameters required to trigger the above loop to do the heavy lifting of the sorting.
# Could probably be optimized into a function instead, but I don't think there's an
# advantage performance-wise. Suggestions are welcome at the URL at the top.
for x in "${FILETYPES[@]}"; do
	# Check for the presence of imagemagick and the identify command.
	# Check for the presence of exiftool and the cksum command.
	# Assuming its valid and working if found.
	I=`which identify`
	if [ "$I" == "" ]; then
		echo "The 'identify' command is missing or not available."
		echo "Is imagemagick installed?"
		#exit 1
	else
		TOOL_PRESENT_IDENTIFY=TRUE
	fi;
	E=`which exiftool`
	if [ "$E" == "" ]; then
		echo "The 'exiftool' is missing or not available."
		echo "Is exiftool installed?"
	else
		TOOL_PRESENT_EXIFTOOL=TRUE
	fi;
	# Niko;) : If no EXIF reading tools available, stop the script.
	if [ "$TOOL_PRESENT_IDENTIFY" == "FALSE" ] && [ "$TOOL_PRESENT_EXIFTOOL" == "FALSE" ] ; then
		exit 1
	fi;
	TOOL_PRESENT_CHECKSUM=FALSE
	C=`which cksum`
	if [ "$C" == "" ]; then
		echo "The 'cksum' command is missing or not available."
		echo "Is cksum installed?"
	else
		TOOL_PRESENT_CHECKSUM=TRUE
	fi;
	M=`which md5sum`
	if [ "$M" == "" ]; then
		echo "The 'md5sum' command is missing or not available."
		echo "Is md5sum installed?"
		#exit 1
	else
		TOOL_PRESENT_CHECKSUM=TRUE
	fi;
	if [ "$TOOL_PRESENT_CHECKSUM" == "FALSE" ] ; then
		exit 1
	fi;
	echo "Scanning for $x..."
	# FIXME: Eliminate problems with unusual characters in filenames.
	# Currently the exec call will fail and they will be skipped.
	# Niko;) : Ignore files already stored in /noexif folder.
	find . -path ./noexif -prune -o -iname "$x" -print0 -exec sh -c "$0 doAction '{}' $TOOL_PRESENT_EXIFTOOL $TOOL_PRESENT_IDENTIFY" \;
	echo "... end of $x"
done;
# clean up empty directories. Find can do this easily.
# Remove Thumbs.db first because of thumbnail caching
echo -n "Removing Thumbs.db files ... "
find . -name Thumbs.db -delete
echo "done."
echo -n "Removing .picasa.ini files ... "
find . -name .picasa.ini -delete
echo "done."
echo -n "Cleaning up empty directories ... "
find . -empty -delete
echo "done."

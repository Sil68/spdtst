# $Id$
# mhshlib.sh
# ==========
#
#     MMHein.at shell Library, to be included in sh/ksh/bash scripts
#
#     Usage: . mhshlib.sh
#
# Copyright (C) MMHein.at/April 2012
#
#     $Log$
#

#======================================================================
# GLOBAL DEFINITION & DECLARATION SECTION
#======================================================================

####
# global constant definition
####
AWK="/usr/bin/awk"
BASENAME="/usr/bin/basename"
BC="/usr/bin/bc"
BZIP="/usr/bin/bzip2"
CAT="/bin/cat"
CHKIP="/usr/local/bin/chkip.sh"
CHOWN="/usr/sbin/chown"
CURL="/usr/bin/curl"
CUT="/usr/bin/cut"
DATE="/bin/date"
DIRNAME="/usr/bin/dirname"
DOS2UNIX="/usr/local/bin/dos2unix"
ECHO="/bin/echo"
EGREP="/usr/bin/egrep"
EXPR="/bin/expr"
GAWK="/usr/local/bin/gawk"
GETEXTIP="/usr/local/bin/getextip.sh"
GREP="/usr/bin/grep"
GSED="/usr/local/bin/gsed"
HEAD="/usr/bin/head"
ICONV="/usr/bin/iconv"
KEYCHAIN="/usr/local/bin/keychain"
LAUNCHCTL="/bin/launchctl"
LS="/bin/ls"
MKDIR="/bin/mkdir"
MORE="/usr/bin/more"
MYSQLDUMP="/opt/local/bin/mysqldump5"
MYSQLSHOW="/opt/local/bin/mysqlshow5"
PASTE="/usr/bin/paste"
PDFTOTEXT="/usr/local/bin/pdftotext"
PING="/sbin/ping"
PIP="/usr/local/pyenv/shims/pip"
PWD="/bin/pwd"
PYTHON="/usr/local/pyenv/shims/pyton"
RM="/bin/rm"
RSYNC="/usr/bin/rsync"
SCP="/usr/bin/scp"
SDIFF="/usr/bin/sdiff"
SED="/usr/bin/sed"
SORT="/usr/bin/sort"
SPEEDTEST="/usr/local/pyenv/shims/speedtest-cli"
SPLIT="/usr/bin/split"
SSH="/usr/bin/ssh"
SSHAGENT="/usr/bin/ssh-agent"
TAIL="/usr/bin/tail"
TEE="/usr/bin/tee"
TR="/usr/bin/tr"
TRACEROUTE="/usr/sbin/traceroute"
UNAME="/usr/bin/uname"
WC="/usr/bin/wc"
WHICH="/usr/bin/which"

SELFFULL="$0"
SELFPATH="`$DIRNAME "$SELFFULL"`"
_SELF="`$BASENAME "$SELFFULL"`"

STARTDIR="`$PWD`"

F_NO_OUTPUT="/dev/null"
F_OUTPUT_DIR="/var/tmp/${_SELF}"
F_OUTPUT_SUBDIR="`$DATE "+%Y%m%d%H%M%S"`"
F_LOG_DIR="/var/log"
F_LOG="${F_LOG_DIR}/${_SELF}.log"

OPT_SET=1
OPT_UNSET=0

RC_OK=0
RC_USAGE=1
RC_ABORT=255

CURLURL="http://queryip.net/ip/"

CURR_HOST="`$UNAME -n`"
CURR_DATE="`$DATE "+%Y%m%d"`"

####
# global variable declaration
####
v_Func="Init"
v_Dir="`$PWD`"

v_OptOutput=$OPT_UNSET
v_OptOutputDir=$OPT_UNSET
v_OptOutputSubdir=$OPT_UNSET
v_OptLog=$OPT_UNSET

v_OutputDir=$F_OUTPUT_DIR
v_OutputSubdir=$F_OUTPUT_SUBDIR
v_Output=$F_OUTPUT
v_LogDir=$F_LOG_DIR
v_Log=$F_LOG

v_RC=$RC_ABORT

#======================================================================
# FUNCTION & PROCEDURE SECTION
#======================================================================

#-------------------------------------------------------------------------------
# Write to log file
#-------------------------------------------------------------------------------
write_output() {	# $1 ... message

	v_Func="$FUNCNAME"

	local hostname="`$UNAME -n`"
	local datetime="`$DATE "+%b %d %Y %H:%M:%S"`"
    local rc=$RC_ERR

	if [ $v_OptOutput -eq $OPT_UNSET ]
	then
   		echo "$*"
   	else
    	echo "$*" | \
    	$TEE -a "$v_Output" 2>&1 > "$F_NO_OUTPUT"
   	fi

	if [ $v_OptLog -ne $OPT_UNSET ]
	then
    	echo "$datetime $hostname $*" 2>&1 | \
    	$TEE -a "$v_Log" 2>&1 > "$F_NO_OUTPUT"
    fi
    
    rc=$?

    return $rc

} # write_output()

#----------------------------------------------------------------------
# In case of an exception...
#----------------------------------------------------------------------
exception_handler() {

	v_Func="$FUNCNAME"

	write_output "Exception caught -- aborting"

    cd "$STARTDIR"
    exit $RC_ABORT

} # exception_handler()

#----------------------------------------------------------------------
# Regular Exit
#----------------------------------------------------------------------
regular_exit() {	# $1 ... return code

	v_Func="$FUNCNAME"

    cd "$STARTDIR"
    exit $1

} # regular_exit()

#
# end of file
#

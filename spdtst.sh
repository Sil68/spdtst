#!/bin/bash
# spdtst.sh
# =========
#     Measuring the internet speed by facilitating the
#     "speedtest-cli" tool.
#
#     Usage: spdtst.sh [-h] [-C <country>] [-c <city>] [-P] [-p]
#                      [-s <server>] [-S]
#                      [-H <remote host>] [-D <remote directory>]
#                      [-U <remote user>] [-R] [-t]
#                      [-o <outfile>] [-l <logfile>] [-k <keychaincfg>]
#                      [-I] [-d]
#
#         -h ............. print help
#         -C <ctry> ...... server of country to use
#         -c <city> ...... server of city to use
#         -P ............. display list of supported countries
#         -p ............. display list of supported cities
#         -s <srv> ....... server to use
#         -S ............. display list of supported servers
#         -H <rmthost> ... remote host to transfer results/output file to
#         -D <rmtdir> .... remote directory to transfer results/output file to
#         -U <rmtusr> .... remote user to transfer results/output file to
#         -R ............. copy result/output file to remote host
#         -A ............. append result/output to file on remote host
#         -t ............. timestamp results/output file
#         -o <outfile> ... write/append results to file <outfile>
#                          default ("/var/log/spdtst.sh.log")
#         -l <logfile> ... log any output to file <logfile>
#                          default ("/var/log/spdtst.sh-dbg.log")
#         -k <keycfg> .... ssh keychain configuration file to use
#                          default ("~/.keychain/<hostname>-sh")
#         -I ............. install/update/upgrade speedtest
#         -d ............. display some debug information
#
#     Algorithm:
#     :: determine list of servers;
#     :: get one specific for the current location (default: United Kingdom/WIOCC);
#     :: execute speed test with this server;
#     :: save results to file in a formated manner (csv-ish);
#     :: on success a value of 0 is returned.
#
#     Further information on speedtest-cli at
#     (<https://www.howtoforge.com/tutorial/check-internet-speed-with-speedtest-cli-on-ubuntu/>).
#
#     speedtest-cli can be installed via
#
#         pip install speedtest-cli [--upgrade]
#
#     or from the sources obtained from github
#
#         wget https://github.com/sivel/speedtest-cli/archive/master.zip
#
#     Executing this script via a crontab job requires some additional steps
#     carried out in order to get ssh/scp working properly.
#
#     As a pre-requisit "ssh-agent" has to be launched and running in the
#     background with the corresponding keys loaded. This can achieved eg.
#     by facilitating "keychain" (parameter -k <keycfg>) and a crontab entry
#     as follows
#
#         0,5,10,15,20,25,30,35,40,45,50,55 * * * * /usr/local/bin/spdtst.sh -A -H <rmthost> -U <rmtusr> -D "<rmtdir>" -k "/<locusrhome>/.keychain/<lochost>-sh"
#
#     or alternatively directly via "ssh-agent"
#
#         0,5,10,15,20,25,30,35,40,45,50,55 * * * * SSH_AUTH_SOCK=$(lsof -a -p $(pgrep ssh-agent) -U -F n | sed -n 's/^n//p') /usr/local/bin/spdtst.sh -A -H <rmthost> -U <rmtusr> -D "<rmtdir>"
#
# Copyright (C) MMHein.at/January 2017
#======================================================================

#======================================================================
# GLOBAL DEFINITION & DECLARATION SECTION
#======================================================================
[ -s /usr/local/lib/mhshlib.sh ] && . /usr/local/lib/mhshlib.sh

DEF_CTRY="United Kingdom"
DEF_CITY="London"
DEF_SRV="WIOCC"
DEF_DEL=";"

DEF_RHST="10.0.0.10"
DEF_RDIR="/data/logfiles/loghost"
DEF_RUSR=""

F_NO_OUTPUT="/dev/null"
F_OUTPUT="/var/log/`echo "${_SELF}"  | $SED -e "s:\.sh$::g"`.log"
F_LOG="/var/log/`echo "${_SELF}"  | $SED -e "s:\.sh$::g"`-dbg.log"

RC_LSTCTRY=100
RC_LSTCITY=101
RC_LSTSRV=102

v_Func="Init"
v_Dir="`$PWD`"

v_OptCtry=$OPT_UNSET
v_OptCity=$OPT_UNSET
v_OptPrnCtry=$OPT_UNSET
v_OptPrnCity=$OPT_UNSET
v_OptSrv=$OPT_UNSET
v_OptPrnSrv=$OPT_UNSET
v_OptRmtHst=$OPT_UNSET
v_OptRmtDir=$OPT_UNSET
v_OptRmtUsr=$OPT_UNSET
v_OptCpyRmt=$OPT_UNSET
v_OptAppRmt=$OPT_UNSET
v_OptTmStmp=$OPT_UNSET
v_OptOutput=$OPT_UNSET
v_OptLog=$OPT_UNSET
v_OptKeyCfg=$OPT_UNSET
v_OptInstUpd=$OPT_UNSET
v_OptHelp=$OPT_UNSET
v_OptDbg=$OPT_UNSET

v_Ctry="$DEF_CTRY"
v_City="$DEF_CITY"
v_Srv="$DEF_SRV"
v_Rhst="$DEF_RHST"
v_Rdir="$DEF_RDIR"
v_Rusr="$DEF_RUSR"
v_Output="$F_OUTPUT"
v_BOutput="`$BASENAME "$v_Output"`"
v_Log="$F_LOG"
v_KeyCfg="$HOME/.keychain/${CURR_HOST}-sh"
v_BLOG="`$BASENAME "$v_Log"`"

v_spdtstlst=""
v_spdtsthd=""

v_RC=$RC_ABORT

#======================================================================
# FUNCTION & PROCEDURE SECTION
#======================================================================
#----------------------------------------------------------------------
# Debug settings
#----------------------------------------------------------------------
dbgset() {
	
	v_Func="$FUNCNAME"

	write_output "Parameter	Setting		Value"
	write_output "---------	----------	------------------------------"
	write_output "   -C		$v_OptCtry		[$v_Ctry]"
	write_output "   -c		$v_OptCity		[$v_City]"
	write_output "   -P		$v_OptPrnCtry		[---]"
	write_output "   -p		$v_OptPrnCity		[---]"
	write_output "   -s		$v_OptSrv		[$v_Srv"]
	write_output "   -S		$v_OptPrnSrv		[---]"
	write_output "   -H		$v_OptRmtHst		[$v_Rhst"]
	write_output "   -D		$v_OptRmtDir		[$v_Rdir]"
	write_output "   -U		$v_OptRmtUsr		[$v_Rusr]"
	write_output "   -R		$v_OptCpyRmt		[---]"
	write_output "   -A		$v_OptAppRmt		[---]"
	write_output "   -t		$v_OptTmStmp		[---]"
	write_output "   -o		$v_OptOutput		[$v_Output]"
	write_output "   -l		$v_OptLog		[$v_Log]"
	write_output "   -k		$v_OptKeyCfg		[$v_KeyCfg]"
	write_output "   -I		$v_OptInstUpd		[---]"
	write_output "   -h		$v_OptHelp		[---]"
	write_output "   -d		$v_OptDbg		[---]"
	write_output
	
    exit $RC_ABORT
	
} # dbgset()

#----------------------------------------------------------------------
# Print out usage message
#----------------------------------------------------------------------
usage() {

	v_Func="$FUNCNAME"

    write_output "Usage: spdtst.sh [-h] [-d] [-C <country>] [-c <city>] [-P] [-p]"
    write_output "                 [-s <server>] [-S]"
    write_output "                 [-H <remote host>] [-D <remote directory>]"
    write_output "                 [-U <remote user>] [-t] [-o <outfile>] [-l <logfile>]"
	write_output "                 [-k <keychaincfg>] [-I]"
    write_output
    write_output "    -h ............. print help"
    write_output "    -d ............. print some debug information"
    write_output "    -C <ctry> ...... server of country to use"
    write_output "    -c <city> ...... server of city to use"
    write_output "    -P ............. display list of supported countries"
    write_output "    -p ............. display list of supported cities"
    write_output "    -s <srv> ....... server to use"
    write_output "    -S ............. display list of supported servers"
    write_output "    -H <rmthost> ... remote host to transfer results/output file to"
    write_output "    -D <rmtdir> .... remote directory to transfer results/output file to"
    write_output "    -U <rmtusr> .... remote user to transfer results/output file to"
    write_output "    -R ............. copy result/output file to remote host"
    write_output "    -A ............. append result/output to file on remote host"
    write_output "    -t ............. timestamp results/output file"
    write_output "    -o <outfile> ... write/append results to file <outfile>"
    write_output "                     default (\"/var/log/spdtst.sh.log\")"
    write_output "    -l <logfile> ... log any output to file <logfile>"
    write_output "                     default (\"/var/log/spdtst.sh-dbg.log\")"
	write_output "    -k <keycfg> .... ssh keychain configuration file to use"
	write_output "                     default (\"~/.keychain/<hostname>-sh\")"
	write_output "    -I ............. install/update/upgrade speedtest"
    write_output
	
    exit $RC_USAGE

} # usage()

#----------------------------------------------------------------------
# Check command line parameters
#----------------------------------------------------------------------
check_command_line() {	# $* ... command line parameter

	v_Func="$FUNCNAME"

    local arg=""
    local rc=$RC_OK

    args=`getopt hdC:c:Pps:SH:D:U:RAto:l:k:I $*`
    rc=$?

    if [ $rc -ne $RC_OK ] ; then usage ; fi

    set -- $args

    while [ $# -gt 0 ]
    do
    	case "$1" in
	  		-h)
				v_OptHelp=$OPT_SET
	      		usage
	      		break
	      		;;

	  		-d)
				v_OptDbg=$OPT_SET
				break
	      		;;

	 		-C)
				v_OptCtry=$OPT_SET
	     		v_Ctry=$2
	      		shift
	      		;;

	 		-c)
				v_OptCity=$OPT_SET
	     		v_City=$2
	      		shift
	      		;;

	  		-P)
				v_OptPrnCtry=$OPT_SET
				lst_ctry
				break
	      		;;

	  		-p)
				v_OptPrnCity=$OPT_SET
				lst_city
				break
	      		;;

	 		-s)
				v_OptSrv=$OPT_SET
	     		v_Srv=$2
	      		shift
	      		;;

	  		-S)
				v_OptPrnSrv=$OPT_SET
				lst_srv
				break
	      		;;

	 		-H)
				v_OptRmtHst=$OPT_SET
	     		v_Rhst=$2
	      		shift
	      		;;
				
	 		-D)
				v_OptRmtDir=$OPT_SET
	     		v_Rdir=$2
	      		shift
	      		;;

	 		-U)
				v_OptRmtUsr=$OPT_SET
	     		v_Rusr=$2
	      		shift
	      		;;

	 		-R)
				v_OptCpyRmt=$OPT_SET
	      		;;

	 		-A)
				v_OptAppRmt=$OPT_SET
	      		;;

	 		-t)
				v_OptTmStmp=$OPT_SET
	      		;;

	 		-o)
				v_OptOutput=$OPT_SET
	     		v_Output=$2
				v_BOutput="`$BASENAME "$v_Output"`"
	      		shift
	      		;;

	  		-l)
				v_OptLog=$OPT_SET
	      		v_Log=$2
				v_BLOG="`$BASENAME "$v_Log"`"
	      		shift
	      		;;
			
	  		-k)
				v_OptKeyCfg=$OPT_SET
	      		v_KeyCfg=$2
	      		shift
	      		;;
			
			-I)
				v_OptInstUpd=$OPT_SET
				chk_spdtst
				break
				;;
	  
	  		--)
	      		shift
	      		break
	      		;;

	  		*)
	      		usage
	      		break
	      		;;
      	esac

      	shift
    done

    return $rc

} # check_command_line()

#----------------------------------------------------------------------
# check for speedtest and install/update/upgrade required
#----------------------------------------------------------------------
chk_spdtst() {

	v_Func="$FUNCNAME"
	
	local rc=$RC_OK
	
	# check for pip/python
	if [ ! -x "$PIP" ]
	then
		write_log "ERROR: Cannot find \"pip\", which is required to install \"speedtest\" -- Abort"
		write_log
		rc=$RC_ABORT

	# check for speedtest
	else
		if [ ! -x "$SPEEDTEST" ]				# install speedtest
		then
			$PIP install speedtest-cli
		else									# update speedtest
			$PIP install speedtest-cli --upgrade
		fi
		rc=$?
	fi
	
	exit $rc
	
} # chk_spdtst()

#----------------------------------------------------------------------
# display list of supported countries
#----------------------------------------------------------------------
lst_ctry() {
						
	v_Func="$FUNCNAME"

	local spdtstctrylst="`echo "$v_spdtstlst" | \
						  $SED -e "s:^.*(\(.*[,].*\)).*$:\1:g" | \
						  $AWK 'BEGIN { FS=", "} { print $NF }' | \
						  $SORT -u`"
	write_output "$spdtstctrylst"
	__="$spdtstctrylst"

    exit $RC_LSTCTRY

} # lst_ctry()

#----------------------------------------------------------------------
# display list of supported cities
#----------------------------------------------------------------------
lst_city() {
						
	v_Func="$FUNCNAME"

	local spdtstcitylst="`echo "$v_spdtstlst" | \
						  $SED -e "s:^.*(\(.*[,].*\)).*$:\1:g" | \
						  $AWK 'BEGIN { FS=", "} { print $1 }' | \
						  $SORT -u`"
	write_output "$spdtstcitylst"
	__="$spdtstcitylst"
	
    exit $RC_LSTCITY

} # lst_city()

#----------------------------------------------------------------------
# display list of supported servers
#----------------------------------------------------------------------
lst_srv() {
						
	v_Func="$FUNCNAME"

	local spdtstsrvlst="`echo "$v_spdtstlst" | \
						 $AWK 'BEGIN { FS="(" } { print $1 }' | \
						 $AWK 'BEGIN { FS=")" } {gsub("(^[ \t]*)|([ \t]*$)", "", $2) ; print $2 }' | \
						 $SORT -u`"
	write_output "$spdtstsrvlst"
	__="$spdtstsrvlst"

    exit $RC_LSTSRV

} # lst_srv()

#----------------------------------------------------------------------
# determine which server to use for speed measurements
#----------------------------------------------------------------------
get_srv() {				#1 ... location
						#2 ... server
						
	v_Func="$FUNCNAME"

	# obtain list of available servers
	local spdtstsrvloc="`echo "${v_spdtstlst}" | $GREP -i "$1"`"
	local spdtstsrv=""
	
	# determine server to facilitate
	if [ -z "`echo "${spdtstsrvloc}" | $SED -e "s:[ \t]::g"`" ]
	then
		spdtstsrv="`echo "${v_spdtstlst}" | $HEAD -2 | $TAIL -1 | $AWK '{print $1}' | $SED -e "s:[()]::g; s:[ \t]::g"`"
	else
		spdtstsrv="`echo "${spdtstsrvloc}" | $GREP -i "$2" | $AWK '{print $1}' | $SED -e "s:[()]::g; s:[ \t]::g"`"
		if [ -z "${spdtstsrv}" ]
		then
			spdtstsrv="`echo "${spdtstsrvloc}" | $HEAD -1 | $AWK '{print $1}' | $SED -e "s:[()]::g"`"
		fi
	fi
	
	spdtstsrv="`echo "${spdtstsrv}" | $SED -e "s:[ \t]::g"`"
	if [ ! -z "${spdtstsrv}" ]
	then
		spdtstsrv="--server ${spdtstsrv}"
	fi
	
	__="$spdtstsrv"
	
} # get_srv

#----------------------------------------------------------------------
# check remote host
#----------------------------------------------------------------------
chk_rmt_hst() {		# $1 ... remote hostname/host address
					# $2 ... remote user

	v_Func="$FUNCNAME"
	
	local rhst="$1"
	local rusr="$2"
    local rc=$RC_OK
	
	$SSH -q ${rusr}@${rhst} 'exit' 2>&1 > /dev/null
	rc=$?
	[ $rc -eq 0 ] && rc=$RC_OK
	
	return $rc
		
} # chk_rmt_hst()

#----------------------------------------------------------------------
# check file on remote host
#----------------------------------------------------------------------
chk_rmt_file() {	# $1 ... remote hostname/host address
					# $2 ... remote user
					# $3 ... remote file name

	v_Func="$FUNCNAME"

	local rhst="$1"
	local rusr="$2"
	local rfname="$3"
    local rc=$RC_OK
	
	rc=`$SSH -q ${rusr}@${rhst} "ls ${rfname}" 2>&1 | $TEE | $GREP -i "no such file" | $WC -l`
	[ $rc -eq 0 ] && rc=$RC_OK
	
	return $rc
	
} # chk_rmt_file()

#----------------------------------------------------------------------
# copy result/output file to remote host (overwrite existing)
#----------------------------------------------------------------------
rmt_cpy() {			# $1 ... output/result file name
					# $2 ... remote hostname/host address
					# $3 ... remote user
					# $4 ... remote file
	
	v_Func="$FUNCNAME"
	
	local fname="$1"
	local rhst="$2"
	local rusr="$3"
	local rfname="$4"
    local rc=$RC_OK

	if [ -s "$fname" ]
	then
		$SCP -Bq "$fname" ${rusr}@${rhst}:${rfname}
		rc=$?
		[ $rc -eq 0 ] && rc=$RC_OK
	fi
	
	return $rc

} # rmt_cpy()

#----------------------------------------------------------------------
# append current result/output data to file on remote host (append to existing)
#----------------------------------------------------------------------
rmt_app() {			# $1 ... most recent record
					# $2 ... remote hostname/host address
					# $3 ... remote user
					# $4 ... remote file
	
	v_Func="$FUNCNAME"

   	local rec="$1"
	local rhst="$2"
	local rusr="$3"
	local rfname="$4"
	local rc=$RC_OK

	if [ ! -z "$rec" ]
	then
		echo "$rec" | \
		$SSH -q ${rusr}@${rhst} "cat >> ${rfname}"
		rc=$?
		[ $rc -eq 0 ] && rc=$RC_OK
	fi

	return $rc

} # rmt_app()

#----------------------------------------------------------------------
# copy/append result/output file to remote host (append to existing)
#----------------------------------------------------------------------
rmt_cpyapp() {		# $1 ... most recent record
					# $2 ... output/result file name
					# $3 ... remote hostname/host address
					# $4 ... remote user
					# $5 ... remote file
	
	v_Func="$FUNCNAME"
	
	local rec="$1"
	local fname="$2"
	local rhst="$3"
	local rusr="$4"
	local rfname="$5"
    local rc=$RC_OK

	if [ -s "$fname" ]
	then
		# check remote host
		chk_rmt_hst "$rhst" "$rusr"
		rc=$?
		
		# check remote file
		if [ $rc -eq $RC_OK ]
		then
			chk_rmt_file "$rhst" "$rusr" "$rfname"
			rc=$?
			
			# copy instead of appending in case not found
			if [ $rc -ne $RC_OK ]
			then
				v_OptAppRmt=$OPT_UNSET
				v_OptCpyRmt=$OPT_SET
				rc=$RC_OK
			fi
		fi
		
		# transfer results/output
		if [ $rc -eq $RC_OK ]
		then
			[ -s "$v_KeyCfg" ] && . "$v_KeyCfg"
			
			if [ $v_OptAppRmt -eq $OPT_SET ]
			then
				rmt_app "$rec" "$rhst" "$rusr" "$rfname"
			else
				rmt_cpy "$fname" "$rhst" "$rusr" "$rfname"
			fi
			rc=$?
			[ $rc -eq 0 ] && rc=$RC_OK
		fi
	fi

	return $rc

} # rmt_cpyapp()

#----------------------------------------------------------------------
# main
#----------------------------------------------------------------------
main() {	# $* ... command line parameter
	
	v_Func="$FUNCNAME"
	
	local oldOptOutput=$OPT_UNSET
	
	# command line arguments
	v_spdtstlst="`$SPEEDTEST --list`"
	v_spdtsthd="`${SPEEDTEST} --csv-header | $SED -e "s:[,]:"${DEF_DEL}":g"`"
	
	check_command_line "$*"
	[ $v_OptDbg -eq $OPT_SET ] && dbgset
	oldOptOutput=$v_OptOutput
	
	[ $v_OptTmStmp -eq $OPT_SET ] && v_Output="${v_Output}-${CURR_DATE}"
	
	# server to facilitate
	get_srv "$v_Ctry" "$v_Srv"
	spdtstsrv=$__
	
	# measure the internet speed
	spdtstres="`${SPEEDTEST} ${spdtstsrv} --csv --csv-delimiter "${DEF_DEL}"`"
	
	# log results to results/output file
	if [ ! -z "spdtstres" ]
	then
		v_OptOutput=$OPT_SET								# write to file
		[ ! -s "$v_Output" ] && write_output "$v_spdtsthd"
		write_output "$spdtstres"
		v_OptOutput=$oldOptOutput
	fi
	
	# copy/append results/output file to remote host
	if [ $v_OptCpyRmt -eq $OPT_SET -o $v_OptAppRmt -eq $OPT_SET ]
	then
		rmt_cpyapp "$spdtstres" "$v_Output" "$v_Rhst" "$v_Rusr" "${v_Rdir}/${v_BOutput}"
	fi
	
	# return result
	__="${v_spdtsthd}
${spdtstres}"
		
} # main()

#======================================================================
# MAIN SECTION
#======================================================================
trap "exception_handler" 1 2 3 6 9 14 15	# enable exception handling

main "$*"									# main function
v_RC=$RC_OK

trap "" 1 2 3 6 9 14 15						# disable exception handling
regular_exit $v_RC							# regular exit

#======================================================================
# end of file
#
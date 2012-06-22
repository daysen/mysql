
#Generates MySQL backups
# @Author Daysen Veerasamy
# daysen@veerasamy.net
# Created 30-Apr-2012
# Modified 02-May-2012
# Version 1.0

HIST_=4
DUMPDIR_='/backup/mysql'
LOGDIR_='/backup/mysql'
RES_='/root/.myresources'
RCPT_='daysen@veerasamy.net'
MAIL_='/tmp/.mybk.a.out.1'


datefmt()
{
	case $1 in
	m)
		DT_=`date +%d%m%Y_%H%M`
		;;
	d)
		DT_=`date +%d%m%Y`
		;;
	esac
	echo $DT_
}

wrlog()
{
	LOG_="$DUMPDIR_/mybackup--`hostname`-`datefmt d`.log"
	if [ -f $LOG_ ]
	then
		echo "[`datefmt m`:] $1 ..." >> $LOG_
	else
		echo "[`datefmt m`:] $1 ..." > $LOG_	
	fi
}

#checks the database engines used 
myeng()
{
	#arg 1 -> uname
	#arg 2 -> mysql passwd
	#arg 3 -> db_name
	
	DBENG_=1
	TMPF_='/tmp/.myeng.a.out1'
	
	mysqlshow --status $3 -u $1 --password=$2 | awk -F "|" '{print $3}' | sed -e '/^$/d' | grep -vi engine | sort | uniq > $TMPF_
	if [ "`grep -iv "innodb" $TMPF_`"  = "" ]
		then
		#db contains tables of type Innodb only
		DBENG_=0
	fi
	
	echo $DBENG_	
}

#performs MySQL backups
mybck()
{
	#arg 1 -> backup type
	#arg 2 -> databases list
	
	UN_=`cat $RES_ | awk -F : '{print $1}'`
	PS_=`cat $RES_ | awk -F : '{print $2}'`
	case "$1" in 
	-f) 
		mysqldump -u $UN_ --password=$PS_ --lock-all-tables --all-databases --flush-logs --log-error=$DUMPDIR_/ERR_mysql_full--`hostname`-`datefmt m`.err> $DUMPDIR_/mysql_full--`hostname`-`datefmt m`.sql
		wrlog "Executing full database dump"
		cleanup $DUMPDIR_ $HIST_ ERR_mysql_full--`hostname`-`datefmt d`
		;;
	-d)
		if [ "$2" != "" ]
		then
			for DB_ in `echo $2 | xargs -d,`
			do
				if [ `myeng $UN_ $PS_ $DB_` = "1" ]
				then
					mysqldump -u $UN_ --password=$PS_ --databases $DB_ --lock-all-tables --flush-logs --log-error=$DUMPDIR_/ERR_mysql_$DB_--`hostname`-`datefmt m`.err > $DUMPDIR_/mysql_$DB_--`hostname`-`datefmt m`.sql
					wrlog "Executing database dump, DB=$DB_ with --lock-all-tables"
					cleanup $DUMPDIR_ $HIST_ ERR_mysql_$DB_--`hostname`-`datefmt d`
				elif [ `myeng $UN_ $PS_ $DB_` = "0" ]
				then
					mysqldump -u $UN_ --password=$PS_ --databases $DB_ --single-transaction --log-error=$DUMPDIR_/ERR_mysql_$DB_--`hostname`-`datefmt m`.err > $DUMPDIR_/mysql_$DB_--`hostname`-`datefmt m`.sql
					wrlog "Executing database dump, DB=$DB_ with --single-transaction"
					cleanup $DUMPDIR_ $HIST_ ERR_mysql_$DB_--`hostname`-`datefmt d`
				fi
			done
		fi
		;;
	esac
	
	STAT_=`cat $MAIL_`	
	if [ "$STAT_" = "0" ]
	then
		mutt -s "MySQL Backup on `hostname` completed successfully" $RCPT_ < /dev/null
	elif [ "$STAT_" = "1" ]
	then
		> /tmp/mybk.a.out.2
		find $DUMPDIR_ -name ERR_mysql_*--`hostname`-`datefmt d`* > /tmp/mybk.a.out.3
		while read line
		do
			cat $line >> /tmp/mybk.a.out.2
		done < /tmp/mybk.a.out.3
		mutt -s "MySQL Backup on `hostname` completed with errors" $RCPT_ < /tmp/mybk.a.out.2
	fi
}

#displays proper usage
usage()
{
	echo "usage: mybk.sh [-f|-d <comma seperated list of database names>] -h"	
}

cleanup()
{
	#arg 1 -> directory
	#arg 2 -> last days changed	
	#arg 3 -> err filename
	#arg 4 -> db name
	
	INDX_=0
	
	LST_=`find $1 -name $3* | xargs`
	if [ "$LST_" != "" ]
	then
		for L__ in $LST_
		do
			if [ ! -s "$L__" ]
			then
				rm -f $L__
			else
				INDX_=1
			fi
		done
	fi
	
	if [ "$INDX_" = "0" ]
	then
		find $1 -type f -ctime +$2 -regex '*.\(sql\|log\|err\)' -exec rm -f '{}' ';'
	fi
	
	echo $INDX_ > $MAIL_
}

#***** main *******************************************
while getopts ":fd:" ARGS
	do
		case "${ARGS}" in
			f)
				#full database backup
				FULLDB_=1
				;;
			d)
				#specific database backup
				SDB_=1
				;;
			h)
				#usage
				usage
				;;
			*)
				#usage
				usage
				;;
		esac
	done


if [ "$FULLDB_" = "1" ] && [ "$SDB_" = "1" ]
then
	#options are mutually exclusive
	usage
elif [ "$FULLDB_" = "1" ]
then
	mybck -f
elif [ "$SDB_" = "1" ]
then
	mybck -d $2
fi

#***** end main ***************************************



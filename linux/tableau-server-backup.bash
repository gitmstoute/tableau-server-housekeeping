#!/bin/bash
#Tableau Server on Linux Backup Script
#Originally created by Jonathan MacDonald @ The Information Lab

# 	HOW TO USE THIS SCRIPT:
# 		Run the setup script to fetch the script and install it in your system correctly 
#
#		Test that the script works in your environment by running it manually
#			You must execute the script as a user that is a member of the tsmadmin group
#			sudo su -l <tsmusername> -c /var/opt/tableau/tableau_server/scripts/tableau-server-housekeeping.sh <tsmusername> <tsmpassword>
#
#		NOTE you have to add your tsm username and password at the end of the command to execute the script. 
#			This avoids you having to hardcode credentials into the script itself
#
#		*UPDATE* starting in 2019.2 the above requirement to include credentials will no longer be necessary,
# 			provided the user executing the script is a member of the tsmadmin group  
#
#		Schedule the script using cron to run on a regular basis
#			sudo su -l $tsmuser -c "crontab -e"
#		
#		For example, to schedule it to run once a day at 01:00, add this to your crontab
#			0 1 * * * /var/opt/tableau/tableau_server/scripts/tableau-server-housekeeping-linux.sh > /home/<tsmuser>/tableau-server-housekeeping.log

#VARIABLES SECTION
# Set some variables - you should change these to match your own environment

# Grab the current datetime for timestamping the log entries
TIMESTAMP=`date '+%Y-%m-%d %H:%M:%S'`
# Do you want to copy your backups to another location after completion?
copy_backup="no"
# If yes to above, where do you want to copy them? 
external_backup_path="/tmp/backups/"
# How many days do you want to keep old backup files for? 
backup_days="7"
# What do you want to name your backup files? (will automatically append current date to this filename)
backup_name="tableau-server-backup"
# Get tsm username from command line input
tsmuser=$1
# Get tsm password from command line input
tsmpassword=$2 

# END OF VARIABLES SECTION

# LOAD ENVIRONMENT & USER INPUT

# Load the Tableau Server environment variables into the cron environment
source /etc/profile.d/tableau_server.sh

# In case that doesn't work then this might do it 
load_environment_file() {
  if [[ -f /etc/opt/tableau/tableau_server/environment.bash ]]; then
    source /etc/opt/tableau/tableau_server/environment.bash
    env_file_exists=1
  fi
}

# BACKUP SECTION

# get the path to the backups folder
backup_path=$(tsm configuration get -k basefilepath.backuprestore -u $tsmuser -p $tsmpassword)
echo $TIMESTAMP "The path for storing backups is $backup_path" 

# count the number of backup files eligible for deletion and output 
echo $TIMESTAMP "Cleaning up old backups..."
lines=$(find $backup_path -type f -name '*.tsbak' -mtime +$backup_days | wc -l)
if [ $lines -eq 0 ]; then 
	echo $TIMESTAMP $lines old backups found, skipping...
	else $TIMESTAMP $lines old backups found, deleting...
		#remove backup files older than N days
		find $backup_path -type f -name '*.tsbak' -mtime +$backup_days -exec rm {} \;
fi

#export current settings
echo $TIMESTAMP "Exporting current settings..."
tsm settings export -f $backup_path/settings.json -u $tsmuser -p $tsmpassword

#create current backup
echo $TIMESTAMP "Backup up Tableau Server data..."
tsm maintenance backup -f $backup_name -d -u $tsmuser -p $tsmpassword

#copy backups to different location (optional)
if [ "$copy_backup" == "yes" ];
	then
	echo $TIMESTAMP "Copying backup and settings to remote share"
	cp $backup_path/* $external_backup_path/
fi

# END OF BACKUP SECTION

# END OF SCRIPT
echo $TIMESTAMP "Backup completed"

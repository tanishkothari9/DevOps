# System Information Script

A bash script that reports basic details about the system, prompts the user for input, makes a directory and a file from that input, and writes the process list into that file through output redirection.

## What the script does
- Shows today's date
- Shows the machine's hostname
- Shows the logged-in user
- Shows how much disk space is in use
- Shows the processes currently running
- Keeps values in variables so they can be reused
- Collects user input through `read -p`
- Makes a directory with `mkdir`
- Makes a file with `touch`
- Writes the process list into that file by redirecting output with `>`

## Commands used
`mkdir`, `touch`, `echo`, `df`, `ps`, `read -p`, variables, `>` output redirection

## The script (sysinfo.sh)
```bash
#!/bin/bash
# System Information Script

# Store data in variables
CURRENT_DATE=$(date)
HOST_NAME=$(hostname)
USER_NAME=$(whoami)

echo "=============================="
echo " SYSTEM INFORMATION"
echo "=============================="

echo "Current Date : $CURRENT_DATE"
echo "Hostname     : $HOST_NAME"
echo "Username     : $USER_NAME"

echo ""
echo "----- Disk Usage -----"
df -h

echo ""
echo "----- Running Processes -----"
ps aux

# Take input from the user
read -p "Enter a name for the report directory: " DIR_NAME
read -p "Enter a name for the report file: " FILE_NAME

# Create directory and file
mkdir -p "$DIR_NAME"
touch "$DIR_NAME/$FILE_NAME"

# Store running processes in the file using output redirection
ps aux > "$DIR_NAME/$FILE_NAME"

echo ""
echo "Running processes saved to: $DIR_NAME/$FILE_NAME"
```

## How to run
```bash
chmod +x sysinfo.sh
./sysinfo.sh
```

## Sample output
```
==============================
 SYSTEM INFORMATION
==============================
Current Date : Wed Sep  2 21:38:56 IST 2026
Hostname     : my-machine
Username     : student

----- Disk Usage -----
Filesystem      Size  Used Avail Use% Mounted on
/dev/sda1        50G   16G   32G  34% /
tmpfs           2.0G     0  2.0G   0% /dev/shm

----- Running Processes -----
USER     PID  %CPU %MEM    VSZ   RSS TTY   STAT START   TIME COMMAND
root       1   0.0  0.1 168000 11000 ?     Ss   09:10   0:01 /sbin/init
student  842   0.3  0.5  95000 40000 pts/0 S+   09:38   0:00 bash sysinfo.sh
...

Enter a name for the report directory: reports
Enter a name for the report file: processes.txt

Running processes saved to: reports/processes.txt
```

## Result
Once the script finishes there is a new `reports/` folder holding `processes.txt`, and inside that file sits the complete `ps aux` listing that the `>` operator redirected into it.

## Screenshots

The script executing, with the date, hostname, user, disk figures, and process list on display:

![System information output](screenshots/image.png)

The tail of the process listing, followed by the two `read -p` prompts and the message confirming the save:

![User input and saved confirmation](<screenshots/image copy.png>)

A look inside the generated file, proving the process list was captured through `>` redirection:

![Saved processes file](<screenshots/image copy 2.png>)

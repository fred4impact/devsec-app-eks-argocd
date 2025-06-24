# Shell Scripting Learning Guide for Beginners

This guide provides essential shell scripting knowledge, common commands, examples, and best practices for beginners working with Linux/Unix systems and DevOps.

---

## Table of Contents

1. [Basic Shell Concepts](#basic-shell-concepts)
2. [Essential Commands](#essential-commands)
3. [Variables and Data Types](#variables-and-data-types)
4. [Control Structures](#control-structures)
5. [Functions](#functions)
6. [File Operations](#file-operations)
7. [Text Processing](#text-processing)
8. [System Administration](#system-administration)
9. [Error Handling](#error-handling)
10. [Best Practices](#best-practices)
11. [Common Scripts](#common-scripts)
12. [Learning Resources](#learning-resources)

---

## Basic Shell Concepts

### What is a Shell?
A shell is a command-line interface that allows you to interact with the operating system. Common shells include:
- **Bash** (Bourne Again Shell) - Most common on Linux
- **Zsh** (Z Shell) - Popular on macOS
- **Fish** - User-friendly shell
- **PowerShell** - Windows shell

### Shebang Line
Every shell script should start with a shebang line:
```bash
#!/bin/bash
```
This tells the system which interpreter to use.

---

## Essential Commands

### 1. File and Directory Operations

```bash
# List files and directories
ls -la                    # List all files with details
ls -lh                    # List with human-readable sizes
ls -t                     # Sort by modification time

# Change directory
cd /path/to/directory     # Change to specific directory
cd ~                      # Go to home directory
cd ..                     # Go up one directory
cd -                      # Go to previous directory

# Create directories
mkdir directory_name      # Create single directory
mkdir -p /path/to/dir     # Create nested directories

# Remove files and directories
rm filename               # Remove file
rm -rf directory          # Remove directory and contents (dangerous!)
rm -i filename            # Interactive removal (ask before deleting)

# Copy and move
cp source destination     # Copy file
cp -r source dest         # Copy directory recursively
mv old_name new_name      # Rename or move file
```

### 2. File Viewing and Editing

```bash
# View file contents
cat filename              # Display entire file
head -n 10 filename       # Show first 10 lines
tail -n 10 filename       # Show last 10 lines
tail -f filename          # Follow file in real-time (useful for logs)

# Search in files
grep "pattern" filename   # Search for pattern in file
grep -i "pattern" file    # Case-insensitive search
grep -r "pattern" dir     # Search recursively in directory
grep -v "pattern" file    # Show lines NOT matching pattern

# Text editors
nano filename             # Simple text editor
vim filename              # Advanced text editor
```

### 3. System Information

```bash
# System information
uname -a                  # System information
whoami                    # Current user
pwd                       # Current working directory
date                      # Current date and time
uptime                    # System uptime

# Process management
ps aux                    # List all processes
top                       # Interactive process viewer
htop                      # Enhanced top (if installed)
kill process_id           # Kill process by ID
killall process_name      # Kill all processes by name
```

### 4. Network Commands

```bash
# Network connectivity
ping google.com           # Test connectivity
curl -I http://example.com # HTTP request
wget http://example.com   # Download file
ssh user@host             # SSH connection
scp file user@host:path   # Copy file over SSH

# Network information
netstat -tuln             # Show listening ports
ss -tuln                  # Modern alternative to netstat
ifconfig                  # Network interface info (deprecated)
ip addr                   # Modern network interface info
```

---

## Variables and Data Types

### Variable Declaration and Usage

```bash
#!/bin/bash

# Basic variable assignment
name="John"
age=25
echo "Hello, $name! You are $age years old."

# Command substitution
current_date=$(date)
echo "Current date: $current_date"

# Arithmetic operations
a=10
b=5
sum=$((a + b))
echo "Sum: $sum"

# String operations
greeting="Hello World"
length=${#greeting}
echo "Length: $length"

# Substring
substring=${greeting:0:5}
echo "Substring: $substring"
```

### Environment Variables

```bash
#!/bin/bash

# Common environment variables
echo "User: $USER"
echo "Home: $HOME"
echo "Path: $PATH"
echo "Shell: $SHELL"

# Set environment variable
export MY_VAR="my_value"
echo "My variable: $MY_VAR"

# Read user input
read -p "Enter your name: " user_name
echo "Hello, $user_name!"
```

---

## Control Structures

### 1. Conditional Statements

```bash
#!/bin/bash

# Simple if statement
if [ -f "file.txt" ]; then
    echo "File exists"
fi

# If-else statement
if [ -d "directory" ]; then
    echo "Directory exists"
else
    echo "Directory does not exist"
fi

# If-elif-else statement
age=18
if [ $age -lt 13 ]; then
    echo "Child"
elif [ $age -lt 20 ]; then
    echo "Teenager"
else
    echo "Adult"
fi

# String comparison
name="John"
if [ "$name" = "John" ]; then
    echo "Hello John!"
fi

# File tests
if [ -r "file.txt" ]; then
    echo "File is readable"
fi

if [ -w "file.txt" ]; then
    echo "File is writable"
fi

if [ -x "script.sh" ]; then
    echo "Script is executable"
fi
```

### 2. Loops

```bash
#!/bin/bash

# For loop with range
for i in {1..5}; do
    echo "Number: $i"
done

# For loop with list
for fruit in apple banana orange; do
    echo "Fruit: $fruit"
done

# For loop with command output
for file in $(ls *.txt); do
    echo "Processing: $file"
done

# While loop
counter=1
while [ $counter -le 5 ]; do
    echo "Counter: $counter"
    ((counter++))
done

# Until loop
counter=1
until [ $counter -gt 5 ]; do
    echo "Counter: $counter"
    ((counter++))
done

# Break and continue
for i in {1..10}; do
    if [ $i -eq 5 ]; then
        break  # Exit loop
    fi
    if [ $i -eq 3 ]; then
        continue  # Skip iteration
    fi
    echo "Number: $i"
done
```

---

## Functions

### Function Definition and Usage

```bash
#!/bin/bash

# Simple function
greet() {
    echo "Hello, $1!"
}

# Call function with parameter
greet "John"

# Function with return value
add() {
    local sum=$(( $1 + $2 ))
    return $sum
}

add 5 3
result=$?
echo "Sum: $result"

# Function with local variables
calculate_area() {
    local width=$1
    local height=$2
    local area=$((width * height))
    echo $area
}

area=$(calculate_area 10 5)
echo "Area: $area"
```

---

## File Operations

### Advanced File Operations

```bash
#!/bin/bash

# Check if file exists
if [ -f "file.txt" ]; then
    echo "File exists"
fi

# Check if directory exists
if [ -d "directory" ]; then
    echo "Directory exists"
fi

# Create backup of file
cp original.txt original.txt.backup

# Find files
find . -name "*.txt" -type f
find . -mtime -7 -name "*.log"  # Files modified in last 7 days

# Count lines in file
line_count=$(wc -l < file.txt)
echo "Lines: $line_count"

# Check file size
file_size=$(stat -f%z file.txt)  # macOS
# file_size=$(stat -c%s file.txt)  # Linux
echo "Size: $file_size bytes"
```

---

## Text Processing

### Advanced Text Processing

```bash
#!/bin/bash

# Sed - Stream editor
sed 's/old/new/g' file.txt                    # Replace text
sed -i 's/old/new/g' file.txt                 # Replace in place
sed -n '1,5p' file.txt                        # Print lines 1-5

# Awk - Text processing
awk '{print $1}' file.txt                     # Print first column
awk '{sum += $1} END {print sum}' file.txt    # Sum first column
awk -F',' '{print $2}' file.txt               # Use comma as delimiter

# Cut - Extract sections
cut -d',' -f1,3 file.txt                      # Extract columns 1 and 3
cut -c1-10 file.txt                           # Extract characters 1-10

# Sort and unique
sort file.txt                                 # Sort lines
sort -u file.txt                              # Sort and remove duplicates
sort -n file.txt                              # Numeric sort

# Join files
join file1.txt file2.txt                      # Join files on common field
```

---

## System Administration

### System Administration Scripts

```bash
#!/bin/bash

# Check disk usage
disk_usage() {
    df -h | grep -E '^/dev/'
}

# Check memory usage
memory_usage() {
    free -h
}

# Check system load
system_load() {
    uptime
}

# List running services
running_services() {
    systemctl list-units --type=service --state=running
}

# Check log files
check_logs() {
    tail -n 50 /var/log/syslog
}

# Backup important files
backup_files() {
    local backup_dir="/backup/$(date +%Y%m%d)"
    mkdir -p "$backup_dir"
    tar -czf "$backup_dir/backup.tar.gz" /important/directory
    echo "Backup created: $backup_dir/backup.tar.gz"
}
```

---

## Error Handling

### Error Handling Techniques

```bash
#!/bin/bash

# Exit on error
set -e

# Exit on undefined variable
set -u

# Print commands before execution
set -x

# Function to handle errors
error_handler() {
    echo "Error occurred in line $1"
    exit 1
}

# Set error handler
trap 'error_handler $LINENO' ERR

# Check if command succeeded
if command; then
    echo "Command succeeded"
else
    echo "Command failed"
fi

# Check exit status
command
if [ $? -eq 0 ]; then
    echo "Success"
else
    echo "Failed with exit code $?"
fi
```

---

## Best Practices

### 1. Script Structure

```bash
#!/bin/bash
#
# Script Name: example.sh
# Description: Brief description of what the script does
# Author: Your Name
# Date: 2024-01-01
# Version: 1.0
#

# Exit on error, undefined variable, and pipe failure
set -euo pipefail

# Constants
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_FILE="/var/log/script.log"

# Functions
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Main function
main() {
    log_message "Script started"
    
    # Your script logic here
    
    log_message "Script completed successfully"
}

# Call main function
main "$@"
```

### 2. Input Validation

```bash
#!/bin/bash

# Validate number of arguments
if [ $# -ne 2 ]; then
    echo "Usage: $0 <source> <destination>"
    exit 1
fi

# Validate file existence
if [ ! -f "$1" ]; then
    echo "Error: Source file '$1' does not exist"
    exit 1
fi

# Validate directory existence
if [ ! -d "$(dirname "$2")" ]; then
    echo "Error: Destination directory does not exist"
    exit 1
fi
```

### 3. Configuration Management

```bash
#!/bin/bash

# Configuration file
CONFIG_FILE="config.conf"

# Load configuration
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    # Default values
    DB_HOST="localhost"
    DB_PORT="3306"
    DB_USER="root"
    DB_PASS=""
fi

# Validate configuration
if [ -z "$DB_HOST" ] || [ -z "$DB_USER" ]; then
    echo "Error: Invalid configuration"
    exit 1
fi
```

---

## Common Scripts

### 1. System Monitoring Script

```bash
#!/bin/bash
# system_monitor.sh

LOG_FILE="/var/log/system_monitor.log"
THRESHOLD=80

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

check_disk_usage() {
    local usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ "$usage" -gt "$THRESHOLD" ]; then
        log_message "WARNING: Disk usage is ${usage}%"
        return 1
    fi
    return 0
}

check_memory_usage() {
    local usage=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
    if [ "$usage" -gt "$THRESHOLD" ]; then
        log_message "WARNING: Memory usage is ${usage}%"
        return 1
    fi
    return 0
}

check_cpu_load() {
    local load=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    local threshold=5.0
    if (( $(echo "$load > $threshold" | bc -l) )); then
        log_message "WARNING: CPU load is $load"
        return 1
    fi
    return 0
}

main() {
    log_message "Starting system monitoring"
    
    check_disk_usage
    check_memory_usage
    check_cpu_load
    
    log_message "System monitoring completed"
}

main "$@"
```

### 2. Backup Script

```bash
#!/bin/bash
# backup.sh

SOURCE_DIR="/home/user/documents"
BACKUP_DIR="/backup"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="backup_${DATE}.tar.gz"

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

create_backup() {
    if [ ! -d "$SOURCE_DIR" ]; then
        log_message "ERROR: Source directory does not exist"
        exit 1
    fi
    
    if [ ! -d "$BACKUP_DIR" ]; then
        mkdir -p "$BACKUP_DIR"
        log_message "Created backup directory: $BACKUP_DIR"
    fi
    
    tar -czf "$BACKUP_DIR/$BACKUP_FILE" -C "$(dirname "$SOURCE_DIR")" "$(basename "$SOURCE_DIR")"
    
    if [ $? -eq 0 ]; then
        log_message "Backup created successfully: $BACKUP_FILE"
    else
        log_message "ERROR: Backup failed"
        exit 1
    fi
}

cleanup_old_backups() {
    # Remove backups older than 30 days
    find "$BACKUP_DIR" -name "backup_*.tar.gz" -mtime +30 -delete
    log_message "Cleaned up old backups"
}

main() {
    log_message "Starting backup process"
    create_backup
    cleanup_old_backups
    log_message "Backup process completed"
}

main "$@"
```

### 3. Log Analysis Script

```bash
#!/bin/bash
# log_analyzer.sh

LOG_FILE="/var/log/nginx/access.log"
REPORT_FILE="/tmp/log_report.txt"

analyze_logs() {
    echo "=== Log Analysis Report ===" > "$REPORT_FILE"
    echo "Generated: $(date)" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    
    # Total requests
    total_requests=$(wc -l < "$LOG_FILE")
    echo "Total Requests: $total_requests" >> "$REPORT_FILE"
    
    # Top IP addresses
    echo "Top 10 IP Addresses:" >> "$REPORT_FILE"
    awk '{print $1}' "$LOG_FILE" | sort | uniq -c | sort -nr | head -10 >> "$REPORT_FILE"
    
    # Top requested URLs
    echo "" >> "$REPORT_FILE"
    echo "Top 10 Requested URLs:" >> "$REPORT_FILE"
    awk '{print $7}' "$LOG_FILE" | sort | uniq -c | sort -nr | head -10 >> "$REPORT_FILE"
    
    # HTTP status codes
    echo "" >> "$REPORT_FILE"
    echo "HTTP Status Codes:" >> "$REPORT_FILE"
    awk '{print $9}' "$LOG_FILE" | sort | uniq -c | sort -nr >> "$REPORT_FILE"
    
    echo "Report generated: $REPORT_FILE"
}

main() {
    if [ ! -f "$LOG_FILE" ]; then
        echo "ERROR: Log file not found: $LOG_FILE"
        exit 1
    fi
    
    analyze_logs
}

main "$@"
```

---

## Learning Resources

### 1. Online Resources
- **Bash Reference Manual**: https://www.gnu.org/software/bash/manual/
- **Shell Scripting Tutorial**: https://www.shellscript.sh/
- **Advanced Bash-Scripting Guide**: https://tldp.org/LDP/abs/html/
- **Bash Hackers Wiki**: https://wiki.bash-hackers.org/

### 2. Books
- "Learning the bash Shell" by Cameron Newham
- "Shell Scripting: Expert Recipes for Linux, Bash and more" by Steve Parker
- "The Linux Command Line" by William Shotts

### 3. Practice Platforms
- **HackerRank**: Shell scripting challenges
- **LeetCode**: Some shell scripting problems
- **Exercism**: Bash track
- **CodeWars**: Shell scripting katas

### 4. Tools for Learning
- **ShellCheck**: Static analysis tool for shell scripts
- **Bash Debug**: Debugging tool for bash scripts
- **Explain Shell**: Online tool to explain shell commands

---

## Tips for Beginners

### 1. Start Small
- Begin with simple scripts that automate repetitive tasks
- Gradually increase complexity
- Practice with real-world scenarios

### 2. Use Comments
- Comment your code extensively
- Explain complex logic
- Document function purposes

### 3. Test Thoroughly
- Test scripts with various inputs
- Handle edge cases
- Validate user input

### 4. Follow Conventions
- Use consistent naming conventions
- Follow shell scripting best practices
- Use proper indentation

### 5. Learn from Others
- Read existing scripts
- Study open-source projects
- Participate in shell scripting communities

### 6. Use Version Control
- Keep your scripts in Git
- Document changes
- Maintain backup copies

---

## Common Pitfalls to Avoid

1. **Not quoting variables**: Always quote variables to handle spaces and special characters
2. **Ignoring exit codes**: Always check if commands succeeded
3. **Hardcoding paths**: Use variables for paths and make scripts portable
4. **Not handling errors**: Implement proper error handling
5. **Using deprecated commands**: Stay updated with modern shell features
6. **Not testing scripts**: Always test before running in production

---

## Conclusion

Shell scripting is a powerful skill for system administration, DevOps, and automation. Start with the basics, practice regularly, and gradually build more complex scripts. Remember to follow best practices, handle errors properly, and always test your scripts before using them in production environments.

The key to becoming proficient in shell scripting is practice and real-world application. Start with simple automation tasks and gradually work your way up to more complex system administration and DevOps scripts. 
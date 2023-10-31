# yb-tools
Inventing some tools to ease life in YB. This is specifically for only support use, for public users it won't work.

:mega: This is One click script to analyse the core dump files. Here are the quick steps to Run it from Lincoln (case file server).

:arrow_right:   Steps:
1. Goto the Lincoln server and the case dir where your core files are available.
2. Run the script /home/support/bin/dump_analyser.sh .
3. Enter the core file name.
     NOTE: core file should NOT be in compressed format.
4. Sit back, Relax! Let the script to setup few things.
5. As soon as you see the lldb console just type the desired command. For example two most used command.
• For top backtrace:

(lldb) bt
• For all backtrace:

(lldb) thread backtrace all
:beer: All set! Your stack traces are on your screen. Want to see how this looks like in action? See below: 

```
support@lincoln:/cases/5534/2023-02-10T11_33_34$ /home/support/bin/dump_analyser.sh
Enter the Core dump file name:
core_yb-tserver.12015
Great! The core dump file provided is a valid core dump, proceeding with analysis of core dump.
Extracting yugabyte binary version information, please wait...

Yugabyte binary version extraction completed.
--------------------------------------------------------
The final URL is: https://downloads.yugabyte.com/releases/2.12.5.0/yugabyte-2.12.5.0-b24-linux-x86_64.tar.gz
The file yugabyte-2.12.5.0-b24-linux-x86_64.tar.gz already exists in /home/yugabyte/yb-software. Skipping the download step.
--------------------------------------------------------
/home/yugabyte/yb-software/yugabyte-2.12.5.0-b24-centos-x86_64 already exists, not extracting again.
--------------------------------------------------------
Executing post_install script to setup the binary as per core dump. Please bear with me!

Post-installation setup completed.
--------------------------------------------------------
Select an option for lldb command and press ENTER:
1. bt
2. thread backtrace all
3. Other lldb command
4. Quit
1
--------------------------------------------------------
Do you want to redirect the output to a file? (y/n)
n
--------------------------------------------------------
(lldb) target create "/home/yugabyte/yb-software/yugabyte-2.12.5.0-b24-centos-x86_64/bin/yb-tserver" --core "core_yb-tserver.12015"
Core file '/cases/5534/2023-02-10T11_33_34/core_yb-tserver.12015' (x86_64) was loaded.
(lldb) bt
* thread #1, name = 'yb-tserver', stop reason = signal SIGSEGV
  * frame #0: 0x00007fd89772b9f3
(lldb)
```

**Known Limitation:**

The script may or may not produce desired core analysis if the customer installed the YB in some custom path. For example below: 

Just for sake I tried to do this on a host with desired dir. I am not sure if the output is different or same just I can see few frames are loaded here more but in previous one it’s not.


```

$ lldb -f /yuga01/home/yugabyte/yb-software/yugabyte-2.12.1.0-b41-centos-x86_64/bin/yb-master -c core_dump_test/core_yb-master.17052
Core file '/home/centos/core_dump_test/core_yb-master.17052' (x86_64) was loaded.
Process 0 stopped
* thread #1: tid = 0, 0x00007f4a86fca0a7, name = 'yb-master', stop reason = signal SIGABRT
    frame #0: 0x00007f4a86fca0a7
-> 0x7f4a86fca0a7:  addb   %al, (%rax)
   0x7f4a86fca0a9:  addb   %al, (%rax)
   0x7f4a86fca0ab:  addb   %al, (%rax)
   0x7f4a86fca0ad:  addb   %al, (%rax)
```

While the other one was showing

```
(lldb) target create "/home/yugabyte/yb-software/yugabyte-2.12.1.0-b41-centos-x86_64/bin/yb-master" --core "core_yb-master.17052"
Core file '/cases/5534/2023-02-10T11_33_34/core_yb-master.17052' (x86_64) was loaded.
(lldb) bt
* thread #1, name = 'yb-master', stop reason = signal SIGABRT
  * frame #0: 0x00007f4a86fca0a7
```



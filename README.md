# docker-vertica
A docker image for Vertica Community, run as single node or multi-node.
Can be found on DockerHub at <https://hub.docker.com/r/fjehl/docker-vertica/>.
It can be used as a sandbox environment for UDF debugging.

## Table of Contents
1. [Common Usage](#common-usage)
    * [Extend it in another Dockerfile](#extend-it-in-another-dockerfile)
    * [Start a single-node cluster](#start-a-single-node-cluster)
    * [Start a multi-node cluster](#start-a-multi-node-cluster)
2. [UDF Development](#udf-development)
3. [Advanced host configuration](#advanced-host-configuration)


## Common usage
This repository provides a Dockerfile and docker-compose.yml that permit starting Vertica respectively:
 - In standalone / single-node mode using **Docker**
 - In cluster mode using **Docker-Compose**
In the two modes, Vertica expects an external volume to be mounted on its **/opt/vertica** which means data is persisted accross container runs.
When started with docker-compose, no configuration is needed on the workstation, everything's declared in the docker-compose.yml file. In pure docker mode, the run command is a little bit more complicated and documented in the following section.

### Extend it in another Dockerfile
You can of course derive an image from this one.
Use the FROM docker directive from within your Dockerfile
```
FROM fjehl/docker-vertica:latest
```

Vertica is started using a verticad [http://supervisord.org/index.html](Supervisor) daemon, that emits a PROCESS_COMMUNICATION_STDOUT event on his stdout file descriptor. You can catch it using event handlers (see Supervisor documentation for this). Basically, your event handler should just send on its stdout a READY command once started, read lines from stdin, and issue a RESULT 2\\nOK once finished, as in the Python script you'll find in the following [http://supervisord.org/events.html](page).
Nevertheless, you child image should 
- Add new supervisord programs or event handlers in /etc/supervisor/conf.d (they will get auto-loaded by the default supervisor.conf)
- Have an entrypoint that runs supervisor like the current image

```
CMD ["/usr/bin/supervisord", "-n"]
```
### Start a single-node cluster
To build and run a single-node cluster, you can use standard docker commands.

#### Building the image
Use docker build inside the image directory.

```
docker build -t fjehl/docker-vertica .
```

#### Starting the container
If you only need a single node cluster, you can use Docker run to run the image.
Given that the RPM is installed at runtime, you need to download Vertica community edition at [http://my.vertica.com](http://my.vertica.com), and store it somewhere: you need to provide it to the container.
You also need to provide a directory mounted as /opt/vertica in the guest. It can be a named volume or any other location on the host.
Don't forget to add the SYS_NICE and SYS_RESOURCE capacities, otherwise the startup script will fail starting Vertica.

```
docker run \
      -v ~/Downloads/vertica-8.0.0-0.x86_64.RHEL6.rpm:/tmp/vertica.rpm \
      -v docker-vertica:/opt/vertica \
      --cap-add SYS_NICE --cap-add SYS_RESOURCE --cap-add SYS_PTRACE\
      --name docker-vertica \
      -ti fjehl/docker-vertica
```

#### Killing the container in a clean way
The container, and especially the vertica startup script (named **verticad**) are designed to handle a SIGINT signal, that will cleanly shutdown Vertica and prevent data corruption.
```
docker kill --signal SIGINT docker-vertica
```
### Start a multi-node cluster
A docker-compose.yml has been designed to ease configuration of a multi-node cluster.

#### Download a Vertica RPM, expose it through an env variable

Go to [the MyVertica website](http://my.vertica.com) and download a CentOS / RHEL version.
Store it somewhere on your system, then export its location to an environment variable:

```
export VERTICA_RPM_PATH=~/Downloads/vertica-X.Y.Z-T.x86_64.RHEL6.rpm
```

#### Building the images
Use docker-compose build inside the image directory.

```
docker-compose build
```

#### Starting the cluster
The cluster is now ready to start. Just submit the "up" command.

```
docker-compose up
```

#### Killing the container in a clean way
The container, and especially the vertica startup script (named **verticad**) are designed to handle a SIGINT signal, that will cleanly shutdown Vertica and prevent data corruption.

```
docker-compose kill -s SIGINT
```
## UDF Development

This container already contains all the useful tools to debug custom UDFs. (GDB and all available symbols).

The following debug examples use [the simple GET_DATA_FROM_NODE() UDF](https://github.com/francoisjehl/getdatafromnode). 

### Start the container with your code mounted

Options are usually the same. You'll just supply a mount point that holds the build binaries.

```
docker run \
      -v ~/Downloads/vertica-8.0.0-0.x86_64.RHEL6.rpm:/tmp/vertica.rpm \
      -v docker-vertica:/opt/vertica \
      -v /home/fjehl/git/vertica-getdatafromnode:/home/fjehl/git/vertica-getdatafromnode \
      --cap-add SYS_NICE --cap-add SYS_RESOURCE --cap-add SYS_PTRACE \
      --name docker-vertica \
      -ti fjehl/docker-vertica
```

### Compile the UDF inside the container

Use your favourite build tool with a docker exec command.
If you're using CMake, an example could look like this:

```
docker exec -ti docker-vertica /bin/bash -c '
  rm -rf /home/dbadmin/lib/build &&
  mkdir /home/dbadmin/lib/build &&
  cd "$_" &&
  cmake .. &&
  make'
```

And would produce the following output:
```
-- The C compiler identification is GNU 4.8.5
-- The CXX compiler identification is GNU 4.8.5
-- Check for working C compiler: /usr/bin/cc
-- Check for working C compiler: /usr/bin/cc -- works
-- Detecting C compiler ABI info
-- Detecting C compiler ABI info - done
-- Check for working CXX compiler: /usr/bin/c++
-- Check for working CXX compiler: /usr/bin/c++ -- works
-- Detecting CXX compiler ABI info
-- Detecting CXX compiler ABI info - done
-- Configuring done
-- Generating done
-- Build files have been written to: /home/dbadmin/lib/build
Scanning dependencies of target getdatafromnode
[ 50%] Building CXX object CMakeFiles/getdatafromnode.dir/src/GetDataFromNode.cpp.o
[100%] Building CXX object CMakeFiles/getdatafromnode.dir/opt/vertica/sdk/include/Vertica.cpp.o
Linking CXX shared library libgetdatafromnode.so
[100%] Built target getdatafromnode
```

There's now a binary, it can be registered.

### Register it in Vertica

You can directly connect from VSQL. Normally, the install script should have written the IP on stdout.
It could be 172.17.0.2, as in the following example.
Connect first to VSQL:

```
vsql -h 172.17.0.2 -U dbadmin
```
Then register the library:

```
CREATE OR REPLACE LIBRARY libgetdatafromnode
  AS '/home/fjehl/git/vertica-getdatafromnode/build/libgetdatafromnode.so';
```
And the functions you want to use.

```
CREATE OR REPLACE TRANSFORM FUNCTION GET_DATA_FROM_NODE 
  AS LANGUAGE 'C++' 
  NAME 'GetDataFromNodeFactory' 
  LIBRARY libgetdatafromnode 
  NOT FENCED;
```

Test that everything seems fine:

```
SELECT
  GET_DATA_FROM_NODE(* USING PARAMETERS node='v_docker_node0001') OVER (PARTITION AUTO) 
FROM public.foo;
```
```
 bar
-----
   1
   2
   3
   4
(4 rows)
```
### Debug it using GDB

Start GDB attached to the running GDBServer, as output by docker run's stdout.

```
(gdb) target extended-remote 172.17.0.2:2159
```

Then attach to Vertica's PID, again as advertised by docker run's stdout.

```
(gdb) attach 116
```

Symbols start to load:
```
GNU gdb (GDB) Red Hat Enterprise Linux 7.6.1-94.el7
Copyright (C) 2013 Free Software Foundation, Inc.
License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.  Type "show copying"
and "show warranty" for details.
This GDB was configured as "x86_64-redhat-linux-gnu".
For bug reporting instructions, please see:
<http://www.gnu.org/software/gdb/bugs/>.
Attaching to process 114
Reading symbols from /opt/vertica/bin/vertica...(no debugging symbols found)...done.
Reading symbols from /opt/vertica/lib/libgssapi_krb5.so.2...(no debugging symbols found)...done.
Loaded symbols for /opt/vertica/lib/libgssapi_krb5.so.2
Reading symbols from /opt/vertica/lib/libkrb5.so.3...(no debugging symbols found)...done.
Loaded symbols for /opt/vertica/lib/libkrb5.so.3
Reading symbols from /opt/vertica/lib/libkrb5support.so.0...(no debugging symbols found)...done.
Loaded symbols for /opt/vertica/lib/libkrb5support.so.0
Reading symbols from /opt/vertica/lib/libk5crypto.so.3...(no debugging symbols found)...done.
Loaded symbols for /opt/vertica/lib/libk5crypto.so.3
Reading symbols from /opt/vertica/lib/libcom_err.so.3...(no debugging symbols found)...done.
```

And you finally get the GDB prompt.

```
(gdb)
```

You can now register code, and set some breakpoints for example:

```
(gdb) directory /home/fjehl/git/vertica-getdatafromnode/src/
(gdb) break /home/fjehl/git/vertica-getdatafromnode/src/GetDataFromNode.cpp:40
```

```
Breakpoint 1 at 0x7f39782ebee0: file /home/fjehl/git/vertica-getdatafromnode/src/GetDataFromNode.cpp, line 40.
```

And restart the execution:
```
(gdb) c
```

The execution continues, as expected:


```
[New Thread 0x7f5b9ab2f700 (LWP 16618)]
[New Thread 0x7f5b9cb33700 (LWP 16619)]
[New Thread 0x7f5b94b0c700 (LWP 16620)]
[New Thread 0x7f5b9c332700 (LWP 16621)]
[New Thread 0x7f5b994db700 (LWP 16622)]
[New Thread 0x7f5b98cda700 (LWP 16623)]
[New Thread 0x7f5b9630f700 (LWP 16624)]
[New Thread 0x7f5b95b0e700 (LWP 16625)]
[New Thread 0x7f5b9530d700 (LWP 16626)]
[New Thread 0x7f5b67fff700 (LWP 16627)]
```

Run the query within another VSQL.
The breakpoint fires:

```
[Switching to Thread 0x7f5b9630f700 (LWP 16624)]

Breakpoint 1, GetDataFromNode::processPartition (this=<optimized out>, srvInterface=..., inputReader=..., outputWriter=...) at /home/dbadmin/lib/src/GetDataFromNode.cpp:40
40	                        for (std::vector<size_t>::iterator i = argCols.begin(); i < argCols.end(); i++)
```

You can now use all the popular GDB commands and features (n, step, bt, etc...) to debug your execution flow.
You can follow this [excellent cheat sheet](http://darkdust.net/files/GDB%20Cheat%20Sheet.pdf) if you never used GDB.

### Debug it in Visual Studio Code

You can use the following configuration. Edit the destination host, path and source files with yours.


```
{
    "version": "0.2.0",
    "configurations": [
        {
            "name": "Launch",
            "type": "cppdbg",
            "request": "launch",
            "program": "/opt/vertica/bin/vertica",
            "setupCommands": [
                {"text": "directory '${workspaceRoot}/vertica-getdatafromnode/src'"},
                {"text": "target extended-remote 172.17.0.2:2159"},
                {"text": "attach 116"}
            ],
            "launchCompleteCommand": "None",
            "filterStderr": false,
            "filterStdout": false,
            "externalConsole": false,
            "cwd": "${workspaceRoot}",
            "logging": {
                "engineLogging": true,
                "trace": true,
                "traceResponse": true
            }
        }
    ]
}
```

## Advanced host configuration
You'll notice that some checks fail during installation. This is because some checks are indeed checking the host machines due to Docker not being a virtualization layer per se. If you want to have a clean install, consider fixing those below.

### Disable CPU frequency scaling
To be performed in the system BIOS

### Disable Transparent Huge Pages (THP)
```
echo always > /sys/kernel/mm/transparent_hugepage/enabled
```
### Set a proper value to vm.min_free_kbytes
```    
sysctl vm.min_free_kbytes=$(echo "scale=0;sqrt($(grep MemTotal /proc/meminfo | awk '{printf "%.0f",$2}')*16)" | bc )
```
### Set a proper value to vm.max_map_count
```   
sysctl vm.vm.max_map_count=$(echo "$(grep MemTotal /proc/meminfo | awk '{printf "%.0f",$2}')/16" | bc)
```

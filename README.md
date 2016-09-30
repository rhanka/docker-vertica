# docker-vertica
A docker image for Vertica Community, run as single node or multi-node.
Can be found on DockerHub at <https://hub.docker.com/r/fjehl/docker-vertica/>

## Usage
This repository provides a Dockerfile and docker-compose.yml that permit starting Vertica respectively:
 - In standalone / single-node mode using **Docker**
 - In cluster mode using **Docker-Compose**
In the two modes, Vertica expects an external volume to be mounted on its **/opt/vertica** which means data is persisted accross container runs.
When started with docker-compose, no configuration is needed on the workstation, everything's declared in the docker-compose.yml file. In pure docker mode, the run command is a little bit more complicated and documented in the following section.

### Single-node cluster
To build and run a single-node cluster, you can use standard docker commands.

#### Building the image
Use docker build inside the image directory.

    docker build -t fjehl/docker-vertica .

#### Starting the container
If you only need a single node cluster, you can use Docker run to run the image.
Given that the RPM is installed at runtime, you need to download Vertica community edition at [http://my.vertica.com](http://my.vertica.com), and store it somewhere: you need to provide it to the container.
You also need to provide a directory mounted as /opt/vertica in the guest. It can be a named volume or any other location on the host.
Don't forget to add the SYS_NICE and SYS_RESOURCE capacities, otherwise the startup script will fail starting Vertica.

    docker run \
      -v ~/Downloads/vertica-8.0.0-0.x86_64.RHEL6.rpm:/tmp/vertica.rpm \
      -v docker-vertica:/opt/vertica \
      --cap-add SYS_NICE --cap-add SYS_RESOURCE \
      --name docker-vertica \
      -ti fjehl/docker-vertica

#### Killing the container in a clean way
The container, and especially the vertica startup script (named **verticad**) are designed to handle a SIGINT signal, that will cleanly shutdown Vertica and prevent data corruption.

    docker kill --signal SIGINT docker-vertica

### Multi-node cluster
A docker-compose.yml has been designed to ease configuration of a multi-node cluster.

#### Building the images
Use docker-compose build inside the image directory.

    docker-compose build

#### Starting the cluster
Given that the RPM is installed at runtime, you need to download Vertica community edition at [http://my.vertica.com](http://my.vertica.com), and store it somewhere. You just need to provide it as an env variable.

    VERTICA_RPM_PATH=~/Downloads/vertica-8.0.0-0.x86_64.RHEL6.rpm \
    docker-compose up

#### Killing the container in a clean way
The container, and especially the vertica startup script (named **verticad**) are designed to handle a SIGINT signal, that will cleanly shutdown Vertica and prevent data corruption.

    docker-compose kill -s SIGINT

## Host configuration
You'll notice that some checks fail during installation. This is because some checks are indeed checking the host machines due to Docker being not a "true" virtualization layer. If you want to have a clean install, consider fixing those below.

### Disable CPU frequency scaling
To be performed in the system BIOS

### Disable Transparent Huge Pages (THP)
    echo always > /sys/kernel/mm/transparent_hugepage/enabled

### Set a proper value to vm.min_free_kbytes
    sysctl vm.min_free_kbytes=$(echo "scale=0;sqrt($(grep MemTotal /proc/meminfo | awk '{printf "%.0f",$2}')*16)" | bc )

### Set a proper value to vm.max_map_count
    sysctl vm.vm.max_map_count=$(echo "$(grep MemTotal /proc/meminfo | awk '{printf "%.0f",$2}')/16" | bc)


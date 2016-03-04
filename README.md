# docker-vertica

A docker image for Vertica Community, run as single node or multi node
Can be found on DockerHub at <https://hub.docker.com/r/fjehl/docker-vertica/>

## Usage

### Build

Download Vertica community edition at my.vertica.com.
Run :

    docker build --build-arg VERTICA_RPM=<vertica_rpm_path> -t fjehl/docker-vertica .

### Run

#### Single Node

    docker run --name vertica fjehl/docker-vertica

#### Multi node
Create a docker network

    docker network create vertica
Run several containers, the last one being responsible of launching the install script.

    docker run --name vertica03 --hostname vertica03 --net=vertica -d fjehl/docker-vertica noinstall
    docker run --name vertica02 --hostname vertica02 --net=vertica -d fjehl/docker-vertica noinstall
    docker run --name vertica01 --hostname vertica01 --net=vertica fjehl/docker-vertica install "vertica01,vertica02,vertica03"

## Host configuration

### Disable CPU frequency scaling
To be performed in the system BIOS

### Disable Transparent Huge Pages (THP)
    echo always > /sys/kernel/mm/transparent_hugepage/enabled

### Set a proper value to vm.min_free_kbytes
    sysctl vm.min_free_kbytes=$(echo "scale=0;sqrt($(grep MemTotal /proc/meminfo | awk '{printf "%.0f",$2}')*16)" | bc )

### Set a proper value to vm.max_map_count
    sysctl vm.vm.max_map_count=$(echo "$(grep MemTotal /proc/meminfo | awk '{printf "%.0f",$2}')/16" | bc)

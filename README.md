# docker-vertica

A docker image for Vertica Community, run as single node or multi node
Can be found on DockerHub at <https://hub.docker.com/r/fjehl/docker-vertica/>

## Usage

### Build

Download Vertica community edition at my.vertica.com.
Edit docker-compose.yml and set the VERTICA_RPM value to the appropriate path on the host

Execute :
    docker-compose build

### Run

Execute:
    docker-compose up

## Host configuration

### Disable CPU frequency scaling
To be performed in the system BIOS

### Disable Transparent Huge Pages (THP)
    echo always > /sys/kernel/mm/transparent_hugepage/enabled

### Set a proper value to vm.min_free_kbytes
    sysctl vm.min_free_kbytes=$(echo "scale=0;sqrt($(grep MemTotal /proc/meminfo | awk '{printf "%.0f",$2}')*16)" | bc )

### Set a proper value to vm.max_map_count
    sysctl vm.vm.max_map_count=$(echo "$(grep MemTotal /proc/meminfo | awk '{printf "%.0f",$2}')/16" | bc)

# coa-box
A Docker image box to run queries on a local Inducks COA database


### Image creation

```bash
bash docker-create-image.sh <image_name>
```

Where 
* `<image_name>` is the desired name of the local image to build from the Dockerfile.

### Container creation

```bash
bash docker-create-container.sh <image_name> <container_name> <host_port>
```

Where
* `<image_name>` is the name of the local image previously built.
* `<container_name>` is the desired name of the container.
* `<host_port>` is the desired host port to bind to MySQL.

### Provisionning

#### 

```bash
docker exec -it <container_name> /bin/bash -c "/home/bperel/coa-provision.sh"
```

Where
* `<container_name>` is the name of the container.
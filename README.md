MemSQL for Openshift
====================

[MemSQL](https://docs.memsql.com/) is a real-time database for cloud and on-premises that delivers immediate insights across live and historical data.

This image is based on [MemSQL official docker image](https://github.com/memsql/memsql-docker-quickstart) ready to be deployed on Openshift.

## Notable Changes
 * Nodes data is stored in `/data/ROLE` and is initialized with default data if it's empty. You must mount `/data` as a volume.
 * Initial schema is read from `/schema/data.sql`, mount it only on first time the container is created. Otherwise it's executed on each container restart.
 
## Usage notes 

Assuming you have an account on AbarCloud and have logged into the [CLI](https://docs.abarcloud.com/management/cli-login.html), you can run the following command to import [our template](https://github.com/abarcloud/abar-templates/tree/master/memsql), which will let you create the required DeploymentConfig and Services on Openshift.
```
oc project MY_PROJECT_HERE

oc create -f https://raw.githubusercontent.com/abarcloud/abar-templates/master/memsql/memsql.yml
```

## Installation
To quickly deploy MemSQL on AbarCloud navigate to Add to Project > Browse Catalog > Data Stores > MemSQL.
This template provides you with basic setup to get started.

For production environment we highly recommended you to fork this repository and customize MemSQL configurations based on your requirements.

## Usage
The template will create a service (i.e. `service/memsql`) that exposes database port 3306 and web UI port 9000.

To access the database use hostname `memsql.MY_PROJECT_NAME.svc.cluster.local` and port `3306`.

## Scaling
The template is based on the [official MemSQL docker image](https://github.com/memsql/memsql-docker-quickstart), with a single master and leaf node both in the same container.

Currently it is only possible to scale vertically by using more memory (navigate to Applications > Deployments > memsql > Actions > Edit Resource Limits).

## Running commands
To execute maintenance commands use the [`oc` CLI](../management/cli-login.md) to start a shell inside the MemSQL pod:
```sh
oc rsh dc/memsql
```

For example, to list the current node states:
```sh
oc rsh dc/memsql

# run commands inside the MemSQL pod:
memsql-ops memsql-list
```

## Web interface
To expose the web interface run the following commands, which will also enable SSL on the route:
```sh
oc expose svc/memsql --port=9000 --name=memsql-web
oc patch route/memsql-web -p '{"spec":{"tls":{"termination":"edge","insecureEdgeTerminationPolicy":"Redirect"}}}'
```

To only [allow your IP to access](https://docs.openshift.org/latest/architecture/networking/routes.html#whitelist) the route:
```sh
oc annotate route memsql-web --overwrite haproxy.router.openshift.io/ip_whitelist="MY_LAPTOP_IP_ADDRESS"
```

Please delete the route when you finish working with the web interface:
```sh
oc delete route/memsql-web
```

We recommend you investigate authentication options for the web interface.

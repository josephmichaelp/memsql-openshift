MemSQL for Openshift
====================

This image is based on [MemSQL official docker image](https://github.com/memsql/memsql-docker-quickstart) ready to be deployed on Openshift.

You can use [this template](https://github.com/abarcloud/abar-templates/tree/master/memsql) to deploy required DeploymentConfig and Services on Openshift.

## Notable Changes
 * Nodes data is stored in `/data/ROLE` and is initialized with default data if it's empty. You must mount `/data` as a volume.
 * Initial schema is read from `/schema/data.sql`, mount it only on first time the container is created. Otherwise it's executed on each container restart.
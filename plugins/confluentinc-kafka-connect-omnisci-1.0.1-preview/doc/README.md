# Introduction

Omnisci Sink Connector for Confluent Kafka Connect to copy records from one or more Kafka Topics into one or more tables in Omnisci.

# Installing OmniSci 

`` docker run --name omniscidb -d -p 6274:6274 omnisci/core-os-cpu:v4.5.0 ``

This will run OmniSci on port 6274. 

To connect to the database, do the following:

1. Run `docker exec -it omniscidb bash` to login to the docker image.
1. Once inside the docker, type `bin/omnisql` (or `bin/mapdql` in older versions) to start the command line client.
1. It will prompt you for a password, the default password id `HyperInteractive`.  
1. The default username is `omnisci`, and the default database is `omnisci` as well. In older versions of OmniSci, these were `mapd` respectively.


# Running Locally
1. Ensure that you have confluent platform installed. Also ensure that confluent bin directory is in your path
2. Make sure docker is installed and setup on your machine as it is used in integration tests.
3. Clone or download the project and run  ``mvn clean install``


# Documentation

Documentation on the connector is hosted on Confluent's
[docs site](https://docs.confluent.io/current/connect/kafka-connect-omnisci/).

Source code is located in Confluent's
[docs repo](https://github.com/confluentinc/docs/tree/master/connect/kafka-connect-omnisci). If changes
are made to configuration options for the connector, be sure to generate the RST docs (as described
below) and open a PR against the docs repo to publish those changes!

# Configs

Documentation on the configurations for each connector can be automatically generated via Maven.

To generate documentation for the sink connector:
```bash
mvn -Pdocs exec:java@sink-config-docs
```

# Compatibility Matrix:

This connector has been tested against the following versions of OmniSci:

1. OmniSci v4.5.0 through OmniSci v4.7.0, CPU version, in a single instance mode (not distributed mode)


# Integration Tests

Our integration test cases work as follows - 

1. We use fabric8's docker-maven-plugin. See pom.xml
1. This plugin creates a new docker image and then launches it just before integration tests start.
1. We pass the ip address of the docker from maven to the integration test via a system property
1. Then, the integration tests connect to the database and do their thing
1. After the integration tests finish, the maven plugin kills the docker image


To run integration tests from Eclipse / IntelliJ: 

1. Run `mvn pre-integration-test` - this will launch OmniSci docker container
1. Then you can run any integration test directly from your IDE
1. When done, use `docker kill` to kill the docker container
  
# Design of Connector

This connector is a wrapper over JDBC Sink Connector. Most of the heavy lifting is done by the JDBC connector. 

## Limitations of OmniSci
OmniSci exposes a JDBC driver, but the driver doesn't support every JDBC feature. Also, while OmniSci speaks SQL,
not all SQL features are suppoprted.

As a result, our connector has several limitations.

1. This connector can only insert data into OmniSci. Updates are not supported.
1. If `auto.create` is enabled, the default values for fields are ignored. This is because OmniSci does not allow default values for columns.
1. If `auto.evolve` is enabled, the connector can only add new columns for fields that are marked optional. Mandatory fields are not supported, even if they have default values.
1. Deletion of fields is not supported. You cannot even delete a field that was previously optional. If you must delete fields, you will have to manually delete the column from the corresponding OmniSci table.


## The Dialect class
The JDBC sink connector has a `Dialect` class - which accounts for differences between various databases.
The dialect generates SQL statements for create/alter tables, insert and upsert statements. It also binds parameters
to a PreparedStatement, creates connections and so on. 
 
The class `GenericDatabaseDialect` in the JDBC sink project does most of the work.

OmniSci specific customizations are available in `OmniSciDatabaseDialect`. This class overrides appropriate 
functions from `GenericDatabaseDialect`.

Dialects are discovered generically - as long as we have a `META-INF/services/io.confluent.connect.jdbc.dialect.DatabaseDialectProvider` file in the classpath.


## The Connector class
Technically, we only need the Dialect for the connector to work. We could just use `JdbcSinkConnector`, and the connector 
would work.

But that would lead to poor user experience, because of the following - 

1. The user would have to specify the dialect explicitly
1. OmniSci doesn't support all features provided by JDBC, and therefore JDBC documentation would be confusing

Besides, OmniSci Sink Connector is enterprise only, while JDBC Sink Connector is open source. This means 
that we still need a way to enforce license checks.

So, we create a specialized `OmniSciSinkConnector` class.

## Specialized ConfigDef

The configuration for OmniSci is 90% similar to the ConfigDef from JDBC. But there is no point
copying all the configuration and redefining it.

So, instead, we clone JDBC's `ConfigDef` at run time, make changes to it, and then create
our own ConfigDef. Because of this - we don't duplicate code, and only make overrides where 
necessary.
   
**IMPORTANT** the specialized ConfigDef is only used to start the connector.
Remember that the connector passes Map<String,?> to the task, and the task
is free to use it's on Configuration class. So `OmniSciConnector` uses the modified
ConfigDef to validate user provided properties - but ultimately passes a Map to the task
in a format that is expected by the underling JdbcSinkTask.



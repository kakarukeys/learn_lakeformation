```
personas created when bootstrapping an AWS account for data lake using AWS LakeFormation
    root user
        - can create IAM admin

    IAM admin
        - can create IAM roles and grant IAM policies
        - can create TF workload identity

    TF workload identity
        - usually with full admin priviledges
        - add itself to data lake admin
        - can create DBs (auto-granted max perms to DB created)
        - can create LF tags (auto-granted max perms to tags created)
        - can associate LF tags to data resources

    data lake admin + arn:aws:iam::aws:policy/AWSLakeFormationDataAdmin = LakeFormation admin
        - cannot change data lake settings
        - can manage all aspects of lakeformation including LF tags and perms

    data lake read-only admin + Read-only IAM perms = LakeFormation Read-only admin
        - checking and auditing of Lake Formation settings and permissions

    service role for lakeformation data access
        - assumed by lakeformation service to allow principals data access to S3 layer

    IAMAllowedPrincipals
        - granted all super LF perms
        - used for transition to LF, should remove after transition is finished

    service roles for data processing
        - granted LF perms, can do data processing, read-write
        - can create tables (auto-granted max perms to tables created and their columns)

    user roles for data queries
        - granted LF perms, can do data queries, usually read-only





backward compatibility/legacy settings
    IAMAllowedPrincipals
        - granted all super LF perms
        - used for transition to LF, should remove after transition is finished

    (Glue)
    AWS Lake Formation > Data catalog settings > Default perms for newly created databases and tables
        - can maintain AWS Glue Data Catalog behaviour
        - allow only IAM access controls to be used
        - should uncheck

    (S3)
    data location, Permission mode
        - Hybrid access mode / Lake Formation mode
        - if hybrid mode, will allow access to principals by IAM perms in addition to LF perms
        - should select LF mode

    (during perm grant)
    hybrid access mode
        - Make Lake Formation permissions effective immediately
        - should check

    cross-account data sharing mode
        - version 1,2,3,4(latest)





There are two AWS accounts A and B, account B has an iceberg table, how does account B share the data with account A, so that account A's user can query the data using Athena?

Assumptions
    1. account A should not process / manipulate data in account B
    2. need not replicate data in account B into account A

1. External glue table
    - create a glue table in account A that points to S3 bucket in account B.
    - need to run a crawler in account A that updates the schema for the bucket data
    - create an LF resource in account A that points to S3 bucket in account B.
    - suitable for situation where account B has no glue schema for the bucket
    - bucket need to grant account A S3 permissions
    ❌ DE team does not like to maintain crawlers

2. catalog share without LF on B (Jeremy's method)
    - on account B
        * grant S3 perms to account A
        * grant glue resource perms to account A
    - on account A
        * create an athena data source
        * grant S3 perms on the correct external buckets to the user
        * grant glue managed policy to the user
    - glue without LF can only control up to table level access
    - glue db, table names must match s3 path fragments to make fine-grained permission grant easy
    - can't be managed by LF on account A
    ❌ does not work with Glue 5.0

3. catalog share with LF on B (Jeremy's method improved)
    - on account B
        * grant LF perms to any IAM roles who want access
        * grant glue resource perms to account A
    - on account A
        * create an athena data source
        * grant glue managed policy to the user
    ❌ does not work with Glue 5.0

4. Resource Access Manager (Yaswanth's method)
    - on account B
        * grant LF perms to account A and any IAM roles who want access
        (RAM takes care of glue resource perm grant, which is abit insecure, as only LF perms control access)
    - on account A
        * accept shares in RAM
        * create a glue db (resource link)
        * associate tags to the glue db
        * grant LF perms to the user (for resource link access)
        * grant glue managed policy to the user

(Note: Glue 4.0 does not support columnar tags, need Glue 5.0 FGAC)





data_engr                - non-sensitive
data_manager             - sensitive
glue_role                - all

hr_manager               - non-sensitive, hr    all, sales sensitive
sales_manger             - non-sensitive, sales all, tech  sensitive
tech_outsourcing_manager - tech all
```

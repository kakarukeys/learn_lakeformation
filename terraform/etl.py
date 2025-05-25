from decimal import Decimal

# Initialize Glue context
import boto3
from awsglue.context import GlueContext
from awsglue.dynamicframe import DynamicFrame
from pyspark.sql import SparkSession
from pyspark.sql.types import StructType, StructField, StringType, IntegerType, DoubleType, DecimalType, BooleanType

# Create SparkSession with GlueContext
spark = SparkSession.builder.appName("example_etl") \
    .config("spark.sql.extensions", "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions") \
    .config("spark.sql.catalog.spark_catalog", "org.apache.iceberg.spark.SparkSessionCatalog") \
    .config("spark.sql.catalog.spark_catalog.catalog-impl", "org.apache.iceberg.aws.glue.GlueCatalog") \
    .config("spark.sql.catalog.spark_catalog.client.region", "ap-southeast-1") \
    .config("spark.sql.catalog.spark_catalog.glue.endpoint", "https://glue.ap-southeast-1.amazonaws.com") \
    .config("spark.sql.catalog.spark_catalog.glue.account-id", "572512847063") \
    .config("spark.sql.catalog.spark_catalog.io-impl", "org.apache.iceberg.aws.s3.S3FileIO") \
    .config("spark.sql.catalog.spark_catalog.warehouse", "s3://iova-iceberg-warehouse/") \
    .getOrCreate()
    # .config("spark.sql.catalog.spark_catalog_b", "org.apache.iceberg.spark.SparkSessionCatalog") \
    # .config("spark.sql.catalog.spark_catalog_b.catalog-impl", "org.apache.iceberg.aws.glue.GlueCatalog") \
    # .config("spark.sql.catalog.spark_catalog_b.client.region", "ap-southeast-1") \
    # .config("spark.sql.catalog.spark_catalog_b.glue.endpoint", "https://glue.ap-southeast-1.amazonaws.com") \
    # .config("spark.sql.catalog.spark_catalog_b.glue.account-id", "769026163231") \
    # .config("spark.sql.catalog.spark_catalog_b.io-impl", "org.apache.iceberg.aws.s3.S3FileIO") \
    # .config("spark.sql.catalog.spark_catalog_b.warehouse", "s3://iova-iceberg-warehouse/") \

glue_context = GlueContext(spark.sparkContext)

# test running SQL on cross-account shared catalog
spark.sql('SELECT * FROM spark_catalog.my_product.tech_team LIMIT 10').show()
# this will trigger error: AnalysisException: [REQUIRES_SINGLE_PART_NAMESPACE] spark_catalog requires a single-part namespace
# spark.sql('SELECT * FROM spark_catalog_b.my_product.tech_team LIMIT 10').show()

# List of dictionaries representing fixed-width data
data_list = [
    {
        "id": "001",
        "name": "John Smith",
        "age": 30,
        "department": "Sales",
        "salary": 1000000.0,
    },
    {
        "id": "002",
        "name": "Jane Doe",
        "age": 28,
        "department": "Marketing",
        "salary": 2000000.0,
    },
    {
        "id": "003",
        "name": "Bob Johnson",
        "age": 45,
        "department": "IT",
        "salary": 3000000.0,
    },
    {
        "id": "004",
        "name": "Alice Brown",
        "age": 32,
        "department": "HR",
        "salary": 1500000.0,
    }
]

# Define schema for the data
schema = StructType([
    StructField("id", StringType(), False),
    StructField("name", StringType(), False),
    StructField("age", IntegerType(), False),
    StructField("department", StringType(), False),
    StructField("salary", DoubleType(), False),
])

lf_tag_by_column = {
    "id": "non-sensitive",
    "name": "sensitive",
    "age": "non-sensitive",
    "department": "non-sensitive",
    "salary": "confidential",
}

# Create DataFrame directly from the list of dictionaries
df = spark.createDataFrame(data_list, schema=schema)

# Display sample of the data
print("Sample of the data:")
df.show()

# Write to Glue database using saveAsTable
target_db = "my_sales"
target_table = "sales_reps"

df.write \
    .format("iceberg") \
    .mode("overwrite") \
    .saveAsTable(name=f"spark_catalog.{target_db}.{target_table}")

print(f"Successfully wrote data to {target_db}.{target_table}")

# lf tagging

def get_lf_tags(client, database_name, table_name):
    response = client.get_resource_lf_tags(
        Resource={
            "Table": {
                "DatabaseName": database_name,
                "Name": table_name,
            }
        }
    )
    return {col["Name"]: {tag["TagKey"]: tag["TagValues"][0] for tag in col["LFTags"]} for col in response["LFTagsOnColumns"]}


def associate_lf_tags(client, database_name, table_name, column_name, tag_key, tag_value):
    resp = client.add_lf_tags_to_resource(
        Resource={
            "TableWithColumns": {
                "DatabaseName": database_name,
                "Name": table_name,
                "ColumnNames": [column_name],
            }
        },
        LFTags=[{"TagKey": tag_key, "TagValues": [tag_value]}],
    )

    if resp["Failures"]:
        raise Exception(resp["Failures"])
        

client = boto3.client("lakeformation")
tags = get_lf_tags(client, target_db, target_table)

for column_name, tag_value in lf_tag_by_column.items():
    if tag_value != tags[column_name]["confidentiality"]:
        associate_lf_tags(client, target_db, target_table, column_name, "confidentiality", tag_value)

# ----------------------------------------------------------------------

data_list = [
    {
        "sku": "xyz-001",
        "name": "ASUS TUF Gaming A15",
        "price": Decimal("1030.20"),
        "monthly_sales": 13,
        "monthly_revenue": Decimal("13392.60"),
    },
    {
        "sku": "xyz-002",
        "name": "Acer Nitro V Gaming",
        "price": Decimal("2030.20"),
        "monthly_sales": 23,
        "monthly_revenue": Decimal("46694.60"),
    },
    {
        "sku": "xyz-003",
        "name": "ASUS ROG Strix G16 Gaming",
        "price": Decimal("3030.20"),
        "monthly_sales": 5,
        "monthly_revenue": Decimal("15151.00"),
    },
    {
        "sku": "xyz-004",
        "name": "ACEMAGIC 2025",
        "price": Decimal("4030.20"),
        "monthly_sales": 0,
        "monthly_revenue": Decimal("0.00"),
    }
]

schema = StructType([
    StructField("sku", StringType(), False),
    StructField("name", StringType(), False),
    StructField("price", DecimalType(10, 2), False),
    StructField("monthly_sales", IntegerType(), False),
    StructField("monthly_revenue", DecimalType(10, 2), False),
])

lf_tag_by_column = {
    "sku": "non-sensitive",
    "name": "non-sensitive",
    "price": "non-sensitive",
    "monthly_sales": "sensitive",
    "monthly_revenue": "confidential",
}

df = spark.createDataFrame(data_list, schema=schema)

target_db = "my_store"
target_table = "retail_sales"

df.write \
    .format("iceberg") \
    .mode("overwrite") \
    .saveAsTable(name=f"spark_catalog.{target_db}.{target_table}")

tags = get_lf_tags(client, target_db, target_table)

for column_name, tag_value in lf_tag_by_column.items():
    if tag_value != tags[column_name]["confidentiality"]:
        associate_lf_tags(client, target_db, target_table, column_name, "confidentiality", tag_value)

# ----------------------------------------------------------------------

data_list = [
    {
        "employee_id": "001",
        "name": "James",
        "pip": False,
    },
    {
        "employee_id": "002",
        "name": "John",
        "pip": False,
    },
    {
        "employee_id": "003",
        "name": "Jane",
        "pip": False,
    },
    {
        "employee_id": "004",
        "name": "Jim",
        "pip": True,
    }
]

schema = StructType([
    StructField("employee_id", StringType(), False),
    StructField("name", StringType(), False),
    StructField("pip", BooleanType(), False),
])

lf_tag_by_column = {
    "employee_id": "non-sensitive",
    "name": "sensitive",
    "pip": "confidential",
}

df = spark.createDataFrame(data_list, schema=schema)

target_db = "success_factor"
target_table = "company_employee"

df.write \
    .format("iceberg") \
    .mode("overwrite") \
    .saveAsTable(name=f"spark_catalog.{target_db}.{target_table}")

tags = get_lf_tags(client, target_db, target_table)

for column_name, tag_value in lf_tag_by_column.items():
    if tag_value != tags[column_name]["confidentiality"]:
        associate_lf_tags(client, target_db, target_table, column_name, "confidentiality", tag_value)

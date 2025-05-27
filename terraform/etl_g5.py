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
    .config("spark.sql.catalog.spark_catalog.client.region", "ap-southeast-1") \
    .config("spark.sql.catalog.spark_catalog.glue.endpoint", "https://glue.ap-southeast-1.amazonaws.com") \
    .config("spark.sql.catalog.spark_catalog.catalog-impl", "org.apache.iceberg.aws.glue.GlueCatalog") \
    .config("spark.sql.catalog.spark_catalog.glue.account-id", "572512847063") \
    .config("spark.sql.catalog.spark_catalog.io-impl", "org.apache.iceberg.aws.s3.S3FileIO") \
    .config("spark.sql.catalog.spark_catalog.warehouse", "s3://iova-iceberg-warehouse/") \
    .config("spark.sql.catalog.spark_catalog_b", "org.apache.iceberg.spark.SparkSessionCatalog") \
    .config("spark.sql.catalog.spark_catalog_b.catalog-impl", "org.apache.iceberg.aws.glue.GlueCatalog") \
    .config("spark.sql.catalog.spark_catalog_b.client.region", "ap-southeast-1") \
    .config("spark.sql.catalog.spark_catalog_b.glue.endpoint", "https://glue.ap-southeast-1.amazonaws.com") \
    .config("spark.sql.catalog.spark_catalog_b.glue.account-id", "769026163231") \
    .config("spark.sql.catalog.spark_catalog_b.io-impl", "org.apache.iceberg.aws.s3.S3FileIO") \
    .config("spark.sql.catalog.spark_catalog_b.warehouse", "s3://iova-iceberg-warehouse/") \
    .getOrCreate()

glue_context = GlueContext(spark.sparkContext)

# test running SQL on cross-account shared catalog
spark.sql('SELECT * FROM spark_catalog_b.my_product.tech_team LIMIT 10').show()

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

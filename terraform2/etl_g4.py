# Initialize Glue context
from awsglue.context import GlueContext
from awsglue.dynamicframe import DynamicFrame
from pyspark.sql import SparkSession
from pyspark.sql.types import StructType, StructField, StringType

# Create SparkSession with GlueContext
spark = SparkSession.builder.appName("example_etl") \
    .config("spark.sql.extensions", "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions") \
    .config("spark.sql.catalog.spark_catalog", "org.apache.iceberg.spark.SparkCatalog") \
    .config("spark.sql.catalog.spark_catalog.catalog-impl", "org.apache.iceberg.aws.glue.GlueCatalog") \
    .config("spark.sql.catalog.spark_catalog.glue.id", "769026163231") \
    .config("spark.sql.catalog.spark_catalog.io-impl", "org.apache.iceberg.aws.s3.S3FileIO") \
    .config("spark.sql.catalog.spark_catalog.glue.lakeformation-enabled", "true") \
    .config("spark.sql.catalog.spark_catalog.warehouse", "s3://natasha-iceberg-warehouse/") \
    .getOrCreate()

glue_context = GlueContext(spark.sparkContext)

# List of dictionaries representing fixed-width data
data_list = [
    {
        "id": "001",
        "email": "john.smith@gmail.com",
        "title": "Product Manager",
        "performance": "good",
    },
    {
        "id": "002",
        "email": "jane@hotmail.com",
        "title": "Frontend Engineer",
        "performance": "good",
    },
    {
        "id": "003",
        "email": "bob@yahoo.com",
        "title": "Backend Engineer",
        "performance": "good",
    },
    {
        "id": "004",
        "email": "alice@protonmail.com",
        "title": "CTO",
        "performance": "poor",
    }
]

# Define schema for the data
schema = StructType([
    StructField("id", StringType(), False),
    StructField("email", StringType(), False),
    StructField("title", StringType(), False),
    StructField("performance", StringType(), False),
])

# Create DataFrame directly from the list of dictionaries
df = spark.createDataFrame(data_list, schema=schema)

# Display sample of the data
print("Sample of the data:")
df.show()

# Write to Glue database using saveAsTable
target_db = "my_product"
target_table = "tech_team"

df.write \
    .format("iceberg") \
    .mode("overwrite") \
    .saveAsTable(name=f"spark_catalog.{target_db}.{target_table}")

print(f"Successfully wrote data to {target_db}.{target_table}")

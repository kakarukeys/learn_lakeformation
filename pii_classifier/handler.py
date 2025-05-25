import json
import time
from itertools import groupby

import boto3


model_id = "apac.amazon.nova-micro-v1:0"

inf_params = {"maxTokens": 300, "topP": 0.1, "topK": 20, "temperature": 0.3}

system_prompt = """
You are a data classifier. You will be given input consisting of a field name followed by 0 to 3 field values.
Determine whether the data is generally considered to be PII, or confidential data or none of the above.
You should only answer a word: pii / confidential / none, for the respective case.
You should not give any explanation.

Below are some examples:
1. Given input: user_email, john@hotmail.com, jane@gmail.com, bob@yahoo.com
You should answer: pii.
2. Given input: fullname, Jeremy Lai, Howard Yu, Tharangni
You should answer: pii.
3. Given input: gross_profit, 123456, 7800000, 6300000
You should answer: confidential.
4. Given input: reach, 12.3, 23.6, 13.5
You should answer: none.
5. Given input: employee_age, 30, 35, 28
You should answer: none.
6. Given input: id, 23, 24, 26
You should answer: none.

"""

tag_value_mapping = {
    "pii": "sensitive",
    "confidential": "confidential",
    "none": "non-sensitive",
}

system_list = [
    {
        "text": system_prompt
    }
]


def classify_data(client, field_name, field_values):
    field_values_str = ", ".join(map(str, field_values))

    message_list = [
        {
            "role": "user",
            "content": [
                {
                    "text": f"{field_name}, {field_values_str}"
                }
            ]
        }
    ]

    native_request = {
        "schemaVersion": "messages-v1",
        "messages": message_list,
        "system": system_list,
        "inferenceConfig": inf_params,
    }

    response = client.invoke_model(modelId=model_id, body=json.dumps(native_request))

    model_response = json.loads(response["body"].read())
    return model_response["output"]["message"]["content"][0]["text"]


def gen_columns(client):
    result1 = client.get_databases()

    for database in result1['DatabaseList']:
        database_name = database['Name']
        result2 = client.get_tables(DatabaseName=database_name)

        for table in result2['TableList']:
            table_name = table['Name']

            for column in table['StorageDescriptor']['Columns']:
                column_name = column['Name']
                yield database_name, table_name, column_name


def get_sample_values(client, database_name, table_name, column_name):
    query = f"""
        SELECT {column_name}
        FROM "{database_name}"."{table_name}"
        WHERE {column_name} IS NOT NULL
        LIMIT 3
    """

    response = client.start_query_execution(
        QueryString=query,
        ResultConfiguration={
            'OutputLocation': 's3://aws-athena-query-results-iova/'
        }
    )
    query_execution_id = response['QueryExecutionId']

    while True:
        response = client.get_query_execution(QueryExecutionId=query_execution_id)
        state = response['QueryExecution']['Status']['State']

        if state == 'SUCCEEDED':
            break
        elif state in ['FAILED', 'CANCELLED']:
            raise Exception(f"Athena query failed: {response['QueryExecution']['Status']['StateChangeReason']}")

        time.sleep(.2)

    response = client.get_query_results(QueryExecutionId=query_execution_id)
    rows = response['ResultSet']['Rows']
    return [row['Data'][0]['VarCharValue'] for row in rows[1:]]


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
    client.add_lf_tags_to_resource(
        Resource={
            "TableWithColumns": {
                "DatabaseName": database_name,
                "Name": table_name,
                "ColumnNames": [column_name],
            }
        },
        LFTags=[{"TagKey": tag_key, "TagValues": [tag_value]}],
    )


def lambda_handler():
    bedrock_client = boto3.client("bedrock-runtime")
    glue_client = boto3.client("glue")
    athena_client = boto3.client('athena')
    lakeformation_client = boto3.client("lakeformation")

    for key, gp in groupby(gen_columns(glue_client), lambda t : t[:2]):
        tags = get_lf_tags(lakeformation_client, *key)

        for database_name, table_name, column_name in gp:
            if tags[column_name]["confidentiality"] == "non-sensitive":
                values = get_sample_values(athena_client, database_name, table_name, column_name)
                verdict = classify_data(bedrock_client, column_name, values)

                print(f"column {database_name}.{table_name}.{column_name} is classified as {verdict}")

                if (tag_value := tag_value_mapping[verdict]) != "non-sensitive":
                    associate_lf_tags(lakeformation_client, database_name, table_name, column_name, "confidentiality", tag_value)


if __name__ == "__main__":
    lambda_handler()

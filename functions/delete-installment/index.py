import json
import os
import ydb
from typing import Union

def handler(event, context):
    try:
        # Get installment ID from path parameters
        installment_id = event['pathParameters']['id']
        
        # Database connection
        endpoint = os.environ['YDB_ENDPOINT']
        database = os.environ['YDB_DATABASE']
        
        driver_config = ydb.DriverConfig(
            endpoint=endpoint,
            database=database,
            credentials=ydb.iam.MetadataUrlCredentials(),
        )
        
        driver = ydb.Driver(driver_config)
        driver.wait(fail_fast=True)
        
        pool = ydb.SessionPool(driver)
        
        def execute_query(session):
            tx = session.transaction(ydb.SerializableReadWrite())

            # First, delete associated payments
            delete_payments_query = """
                DECLARE $installment_id AS Utf8;
                DELETE FROM installment_payments WHERE installment_id = $installment_id;
            """
            tx.execute(
                session.prepare(delete_payments_query),
                {'$installment_id': installment_id}
            )

            # Then, delete the installment itself
            delete_installment_query = """
                DECLARE $installment_id AS Utf8;
                DELETE FROM installments WHERE id = $installment_id;
            """
            tx.execute(
                session.prepare(delete_installment_query),
                {'$installment_id': installment_id}
            )
            
            tx.commit()
        
        try:
            pool.retry_operation_sync(execute_query)
        finally:
            driver.stop()
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type, Authorization',
            },
            'body': json.dumps({'message': 'Installment deleted successfully'})
        }
        
    except Exception as e:
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type, Authorization',
            },
            'body': json.dumps({'error': str(e)})
        } 
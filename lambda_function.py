import json

def lambda_handler(event, context):
    print(f"[lambda_function] Received event: {json.dumps(event)}")
    return { 
        'message' : 'Completed'
    }

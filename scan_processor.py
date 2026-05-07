import json
import boto3
import base64
import urllib.request
from datetime import datetime

# Initialize AWS Services
rekognition = boto3.client('rekognition')
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('AHLMS-Hardware-Logs')

# ServiceNow Configuration
SNOW_INSTANCE = 'https://dev289997.service-now.com'
SNOW_USER = 'admin'
SNOW_PASS = 'YOUR_PASSWORD_HERE'

def create_servicenow_ticket(serial_number, device_type):
    url = f"{SNOW_INSTANCE}/api/now/table/incident"
    auth_str = f"{SNOW_USER}:{SNOW_PASS}"
    b64_auth_str = base64.b64encode(auth_str.encode('ascii')).decode('ascii')
    headers = {
        "Accept": "application/json",
        "Content-Type": "application/json",
        "Authorization": f"Basic {b64_auth_str}"
    }
    body = {
        "short_description": f"AHLMS AI Audit: Decommissioned - {device_type} (SN: {serial_number})",
        "comments": "Automated log via AWS Rekognition Computer Vision."
    }
    req = urllib.request.Request(url, data=json.dumps(body).encode('utf-8'), headers=headers, method='POST')
    try:
        urllib.request.urlopen(req)
    except Exception as e:
        print(f"ServiceNow Error: {str(e)}")

def lambda_handler(event, context):
    body = json.loads(event['body'])
    
    # CASE 1: AI ANALYSIS
    if 'image' in body:
        image_bytes = base64.b64decode(body['image'])
        
        # Call AI to detect ALL text in the image
        response = rekognition.detect_text(Image={'Bytes': image_bytes})
        
        detected_value = "NOT_DETECTED"
        
        # We search through every piece of text found
        for text in response['TextDetections']:
            # 'LINE' detections are usually the most accurate for serial numbers
            if text['Type'] == 'LINE':
                candidate = text['DetectedText'].strip()
                
                # Rule: Usually serial numbers are 4+ characters and not just common words
                if len(candidate) > 3:
                    detected_value = candidate
                    break # Grab the first solid line found
            
        return {
            'statusCode': 200,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Methods': 'OPTIONS,POST'
            },
            'body': json.dumps({'detectedValue': detected_value})
        }

    

    # CASE 2: FINAL SUBMISSION (Logging to Database and ServiceNow)
    serial_number = body.get('SerialNumber', 'UNKNOWN')
    device_type = body.get('DeviceType', 'UNKNOWN')
    
    table.put_item(Item={
        'SerialNumber': serial_number,
        'DeviceType': device_type,
        'Status': 'Decommissioned',
        'Timestamp': str(datetime.now())
    })
    
    create_servicenow_ticket(serial_number, device_type)
    
    return {
        'statusCode': 200,
        'headers': {'Access-Control-Allow-Origin': '*'},
        'body': json.dumps('LOG_SUCCESS')
    }
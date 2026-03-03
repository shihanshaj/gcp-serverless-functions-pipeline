import functions_framework
import base64
import json
from datetime import datetime, timezone

@functions_framework.cloud_event
def event_processor(cloud_event):
    raw_data = base64.b64decode(
        cloud_event.data["message"]["data"]
    ).decode('utf-8')

    print(f"Received: {raw_data}")

    try:
        message_data = json.loads(raw_data)
    except json.JSONDecodeError:
        message_data = {'raw': raw_data}

    print(f"Processed event type: {message_data.get('type', 'unknown')}")
    return 'OK'

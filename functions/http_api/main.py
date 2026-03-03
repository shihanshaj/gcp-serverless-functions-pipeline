import functions_framework
import json
from datetime import datetime, timezone

@functions_framework.http
def http_api(request):
    headers = {'Access-Control-Allow-Origin': '*'}

    if request.method == 'OPTIONS':
        return ('', 204, headers)

    if request.method == 'GET':
        return (json.dumps({'message': 'Hello from Cloud Functions!', 'status': 'healthy'}), 200, headers)

    elif request.method == 'POST':
        data = request.get_json(silent=True)
        if not data or 'name' not in data:
            return (json.dumps({'error': 'name field is required'}), 400, headers)
        item = {
            'name': data['name'],
            'value': data.get('value', 0),
            'created_at': datetime.now(timezone.utc).isoformat()
        }
        return (json.dumps({'message': 'Item created', 'item': item}), 201, headers)

    return (json.dumps({'error': 'Method not allowed'}), 405, headers)

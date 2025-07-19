import os
import urllib3
from urllib.parse import urljoin

TEST_ENDPOINT_URL = os.environ['TEST_ENDPOINT_URL']
http = urllib3.PoolManager()

def lambda_handler(event, context):
    health_check_url = urljoin(TEST_ENDPOINT_URL, '/')
    
    try:
        response = http.request('GET', health_check_url, timeout=30.0)
        return {'hookStatus': 'SUCCEEDED' if response.status == 200 else 'FAILED'}
    except:
        return {'hookStatus': 'FAILED'}
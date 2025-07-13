import os, boto3
from sentence_transformers import SentenceTransformer
from opensearchpy import OpenSearch, RequestsHttpConnection

s3 = boto3.client('s3')
model = SentenceTransformer('all-MiniLM-L6-v2')

def lambda_handler(event, context):
    bucket, key = event['bucket'], event['key']
    local = f"/tmp/{os.path.basename(key)}"
    s3.download_file(bucket, key, local)
    text = open(local).read()
    emb = model.encode([text])[0].tolist()
    gold = os.environ['GOLD_BUCKET']
    s3.put_object(Bucket=gold, Key=key.replace('bronze/', 'gold/'), Body=text)
    host = os.environ['OPENSEARCH_HOST']; auth=(os.environ['OPENSEARCH_USER'], os.environ['OPENSEARCH_PASS'])
    client=OpenSearch(hosts=[{'host':host,'port':443}],http_auth=auth,use_ssl=True,verify_certs=True,connection_class=RequestsHttpConnection)
    client.index(index=os.environ['OPENSEARCH_INDEX'], body={'key': key, 'vector': emb})
    return {'ok': True}
import os, boto3, whisper
from sentence_transformers import SentenceTransformer
from opensearchpy import OpenSearch, RequestsHttpConnection

s3 = boto3.client('s3')
model_whisper = whisper.load_model("base")
model_embed   = SentenceTransformer('all-MiniLM-L6-v2')

def lambda_handler(event, context):
    bucket, key = event['bucket'], event['key']
    local = f"/tmp/{os.path.basename(key)}"
    s3.download_file(bucket, key, local)
    transcript = model_whisper.transcribe(local)['text']
    emb = model_embed.encode([transcript])[0].tolist()
    gold = os.environ['GOLD_BUCKET']; tkey = key.replace('bronze/', 'gold/').rsplit('.',1)[0]+'.txt'
    s3.put_object(Bucket=gold, Key=tkey, Body=transcript)
    host = os.environ['OPENSEARCH_HOST']; auth=(os.environ['OPENSEARCH_USER'], os.environ['OPENSEARCH_PASS'])
    client=OpenSearch(hosts=[{'host':host,'port':443}],http_auth=auth,use_ssl=True,verify_certs=True,connection_class=RequestsHttpConnection)
    client.index(index=os.environ['OPENSEARCH_INDEX'], body={'key': tkey, 'vector': emb})
    return {'ok': True}
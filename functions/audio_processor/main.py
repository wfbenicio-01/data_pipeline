import json

def lambda_handler(event, context):
    s3_path = event.get("s3_path", "")
    # Simulando transcrição de áudio
    return {
        "function": "audio_processor",
        "s3_path": s3_path,
        "transcription": "Simulated transcription of audio"
    }
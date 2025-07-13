import mimetypes

def lambda_handler(event, context):
    file_name = event.get("file_name", "")
    file_type, _ = mimetypes.guess_type(file_name)

    if file_type is None:
        return {"function": "detect_file", "file_type": "unknown"}

    if file_type.startswith("text"):
        return {"function": "detect_file", "file_type": "text"}
    elif file_type.startswith("audio"):
        return {"function": "detect_file", "file_type": "audio"}
    elif file_type.startswith("video"):
        return {"function": "detect_file", "file_type": "video"}
    else:
        return {"function": "detect_file", "file_type": "other"}
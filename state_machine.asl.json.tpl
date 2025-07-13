{
  "Comment": "State machine for file ingest",
  "StartAt": "ProcessFile",
  "States": {
    "ProcessFile": {
      "Type": "Choice",
      "Choices": [
        { "Variable": "$.key", "StringMatches": "*.txt", "Next": "TextProcessor" },
        { "Variable": "$.key", "StringMatches": "*.mp3", "Next": "AudioProcessor" },
        { "Variable": "$.key", "StringMatches": "*.mp4", "Next": "VideoProcessor" }
      ],
      "Default": "TextProcessor"
    },
    "TextProcessor": { "Type": "Task", "Resource": "${text_arn}", "Next": "Done" },
    "AudioProcessor": { "Type": "Task", "Resource": "${audio_arn}", "Next": "Done" },
    "VideoProcessor": { "Type": "Task", "Resource": "${video_arn}", "Next": "Done" },
    "Done":           { "Type": "Succeed" }
  }
}
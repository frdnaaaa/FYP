from dotenv import load_dotenv
load_dotenv()

from flask import Flask, request, jsonify
from transformers import AutomaticSpeechRecognitionPipeline, WhisperForConditionalGeneration, WhisperTokenizer, WhisperProcessor
from peft import PeftModel, PeftConfig
import torch
import os
from enum import Enum
from datetime import datetime
import random
import logging

logging.basicConfig(filename='app.log', level=logging.ERROR)
app = Flask(__name__)

class SpeechRecognizer:
    def __init__(self, peft_model_id, language="malay", task="transcribe"):
        self.language = language
        self.task = task
        self.peft_model_id = peft_model_id
        peft_config = PeftConfig.from_pretrained(self.peft_model_id)

        self.model = WhisperForConditionalGeneration.from_pretrained(
            peft_config.base_model_name_or_path, device_map="cpu"
        )
        self.model = PeftModel.from_pretrained(self.model, self.peft_model_id)
        self.tokenizer = WhisperTokenizer.from_pretrained(peft_config.base_model_name_or_path, language=self.language, task=self.task)
        self.processor = WhisperProcessor.from_pretrained(peft_config.base_model_name_or_path, language=self.language, task=self.task)
        self.feature_extractor = self.processor.feature_extractor
        self.forced_decoder_ids = self.processor.get_decoder_prompt_ids(language=self.language, task=self.task)

        self.pipe = AutomaticSpeechRecognitionPipeline(
            model=self.model, tokenizer=self.tokenizer, feature_extractor=self.feature_extractor
        )

    def transcribe(self, audio_file):
        if torch.cuda.is_available():
            with torch.cuda.amp.autocast():
                result = self.pipe(audio_file, generate_kwargs={"forced_decoder_ids": self.forced_decoder_ids}, max_new_tokens=255)
        else:
            result = self.pipe(audio_file, generate_kwargs={"forced_decoder_ids": self.forced_decoder_ids}, max_new_tokens=255)
        return result["text"]

# Define an enumeration for response statuses
class StatusEnum(Enum):
    SUCCESS = 1
    FAILED = 2
    ERROR = 3

def create_response(status, message, data=None):
    return {
        'Status': status.value,
        'Message': message,
        'Data': data
    }

# Load both models once
recognizer_e20 = SpeechRecognizer(peft_model_id="rdee/whisper-large-peft-malay-e20")
recognizer_e3 = SpeechRecognizer(peft_model_id="clt013/whisper-large-v3-ft-malay-peft-epoch-20")

@app.route('/', methods=['GET'])
def test():
    return 'Server is running'

@app.route('/api/transcribe', methods=['POST'])
def transcribe_audio():
    SECRET_TOKEN = os.getenv("SECRET_TOKEN")

    if 'audio' not in request.files or request.form.get('secret') != SECRET_TOKEN:
        return jsonify(create_response(StatusEnum.ERROR, 'Unauthorized access or no audio file provided')), 403

    audio_file = request.files['audio']
    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    temp_path = f"temp_audio_{timestamp}_{random.randint(1000,9999)}.wav"
    audio_file.save(temp_path)

    try:
        print("Transcribing with E20 model...")
        text_e20 = recognizer_e20.transcribe(temp_path)

        print("Transcribing with E3 model...")
        text_e3 = recognizer_e3.transcribe(temp_path)

        print(f"Output E20: {text_e20}")
        print(f"Output E3: {text_e3}")

        # Heuristic: prefer longer output with fewer unknown tokens
        def score(text):
            return len(text.strip()) - text.count("[UNK]")

        best_transcription = text_e20 if score(text_e20) >= score(text_e3) else text_e3

        return jsonify(create_response(StatusEnum.SUCCESS, 'Transcription successful', best_transcription))

    except Exception as e:
        logging.error(f"Transcription error: {e}")
        return jsonify(create_response(StatusEnum.FAILED, str(e)))

    finally:
        if os.path.exists(temp_path):
            os.remove(temp_path)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)

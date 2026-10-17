# palash-mtb-mle

PALASH Mother Tongue-Based Multilingual Education (MTB-MLE) project for supporting multilingual education and localized learning.

## Overview
This project helps learners and teachers translate content between languages, with a focus on Hindi to Santali language support. It combines translation workflows with speech support so users can speak in one language, view translated text, and hear the translated output spoken aloud.

## Features
- Hindi to Santali translation support
- Dictionary-backed validation for translated terms
- ONNX-based translation pipeline for local inference
- Speech-to-text input for voice-based interaction
- Text-to-speech output for translated text using an approximate Hindi voice; a dedicated Santali TTS voice is not included
- Educational support for multilingual classroom use

## Voice support
The application includes voice interaction features:
- Speak Hindi text using voice input
- Translate the spoken text to Santali
- Convert the translated output to voice so learners can hear the translated result

This makes the tool more accessible for classroom use, low-literacy learners, and multilingual teaching scenarios. Santali output is converted to a Devanagari pronunciation approximation for the device's Hindi speech voice, so pronunciation may vary.

## Project structure
- `android_app/` — Flutter mobile application
- `nlp_models/` — translation and NLP model assets
- `docs/` — project documentation
- `worksheet_generator/` — worksheet generation utilities

## Getting started
See the project directories above and follow the app-specific setup instructions in the Android app README for running the mobile experience.

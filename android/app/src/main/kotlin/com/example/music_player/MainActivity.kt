package com.example.music_player

import com.ryanheise.audioservice.AudioServiceActivity

// AudioServiceActivity is required by just_audio_background / audio_service so
// the FlutterEngine shares the media notification service binding.
class MainActivity : AudioServiceActivity()

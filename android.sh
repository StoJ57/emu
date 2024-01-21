#!/bin/bash

flutter build apk
adb deploy build/app/outputs/flutter-apk/app-release.apk
adb shell am start -a android.intent.action.MAIN -n com.example.emu/.MainActivity

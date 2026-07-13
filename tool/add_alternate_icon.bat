@echo off
setlocal
cd /d "%~dp0add_alternate_icon"
dart pub get
dart run bin/add_alternate_icon.dart %*

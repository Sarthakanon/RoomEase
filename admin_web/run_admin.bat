@echo off
echo Starting RoomEase Admin Panel...
echo.

REM Check if Flutter is installed
where flutter >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo Flutter is not installed. Please install Flutter first.
    exit /b 1
)

REM Get dependencies
echo Getting dependencies...
call flutter pub get

REM Run the admin web app
echo Launching admin panel on http://localhost:8081
echo.
call flutter run -d chrome --web-port=8081 --web-hostname=localhost

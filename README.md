# inspector
fullstack Projekt zur Vereinfachung von Inspektionen

# read doku [here](https://mastbau-fn.github.io/inspector/doc)
backend stuff is not included there, but can be seen [here](https://github.com/Mastbau-FN/inspector/tree/main/backend)

# how to build and run:

### Setup 
- clone this repo
- setup backend ([here](https://github.com/Mastbau-FN/inspector/tree/main/backend/readme.md))
- create .env file in frontend dir
    - needs the same `API_KEY` value as the backend .env
    - and the url of the backend
    <details><summary>example</summary>

    ```
    API_KEY=AE*%kXy2@WqCxNpm+^zz4V*eM93_B3P7
    API_URL=http://192.168.178.40:3000/api/secure

    ```
</details>

### install flutter
- see [here](https://flutter.dev/docs/get-started/install)

### install app
- run `flutter build apk` (inside frontend dir)
- a new file in `frontend\build\app\outputs\apk\release\app-release.apk` appears, get this to an android device somehow 
- click it from the android device, install, run, tada!




@echo off
cls
echo Compiling class files.
javac -d build net/electricadventures/CVSoundFX.java
pause
echo Building JAR file.

jar --create --file CVSoundFX.jar --main-class net.electricadventures.CVSoundFX -C build .

native-image -jar CVSoundFX.jar
echo Done.

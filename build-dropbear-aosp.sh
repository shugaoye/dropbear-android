#!/bin/bash

if [ -z $ANDROID_NDK_HOME ]; then
        echo "ANDROID_NDK_HOME is empty.";
		exit -1;
else
        echo ANDROID_NDK_HOME=${ANDROID_NDK_HOME}
fi

cp Application.mk jni/Application.mk
export NDK_PROJECT_PATH=`pwd`
${ANDROID_NDK_HOME}/ndk-build
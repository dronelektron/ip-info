#!/bin/bash

PLUGIN_NAME="ip-info"

cd scripting
spcomp $PLUGIN_NAME.sp -i include -o ../plugins/$PLUGIN_NAME.smx

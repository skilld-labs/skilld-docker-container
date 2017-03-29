#!/bin/bash
###########
# sdd_theme_init.sh
# This file prepare sdd theme starter kit to project theme.
# To use this file you should provide project_theme name as argument
# Example:
# ./sdd_theme_init.sh project_theme
###########

# Check first argument.
# First argument is required and  used to define the THEME_NAME variable.
if [ -z "$1" ]; then
  echo "Please provide theme name as argument."
  exit;
fi;
THEME_NAME="$1"
DEFAULT_THEME_NAME=projectname_theme

# Rename theme folder.
mv src/themes/${DEFAULT_THEME_NAME} src/themes/${THEME_NAME}
# Rename theme files.
find src/themes/${THEME_NAME} -type f -exec rename "s/${DEFAULT_THEME_NAME}/${THEME_NAME}/" "{}" \;
# Rename src files content.
find src/ -type f -exec sed -i -e "s/${DEFAULT_THEME_NAME}/${THEME_NAME}/g" "{}" \;

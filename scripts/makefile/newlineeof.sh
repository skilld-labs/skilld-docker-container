#!/usr/bin/env sh

# Separate with comma ","
FILES_TO_VALIDATE=.env.default

FILES_TO_VALIDATE_AS_LIST=$(echo "$FILES_TO_VALIDATE" | tr ',' '\n')

echo "Validating newline at the end of file(s) $FILES_TO_VALIDATE..."

for file in $FILES_TO_VALIDATE_AS_LIST; do
	if [ -z "$(tail -c 1 "$file")" ]
	then
	    echo "OK : Newline found at end of $file"
	else
	    printf "\e[33mKO : No newline found at end of $file !\e[0m\n"
	    exit 1
	fi
done

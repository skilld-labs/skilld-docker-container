# Skilld default content

## How to use ?

1. Enable module default_content. It should be already installed by composer.
4. Create content manually on site using UID1 admin user
3. Use `drush dcer` commands (brought by module) to export selected content. Exemple : 
```
drush dcer node 1 --folder=modules/custom/skilld_default_content/content
drush dcer user 5 --folder=modules/custom/skilld_default_content/content
drush dcer block_content 8 --folder=modules/custom/skilld_default_content/content
drush dcer menu_link_content 7 --folder=modules/custom/skilld_default_content/content
drush dcer taxonomy_term <taxonomy term id> --folder=modules/custom/skilld_default_content/content
drush dcer file <file id> --folder=modules/custom/skilld_default_content/content
drush dcer media <media id> --folder=modules/custom/skilld_default_content/content
```
4. Find out what is UUID of admin user : `ls web/modules/custom/skilld_default_content/content/user`
     - 4bad48eb-ff5b-45b4-b30c-ecabff09591a : UUID of default_content_author user
     - the other UUID listed should be admin user
5. Use `sed` commands to replace UID and UUID of admin author in files of all exported content : 
	 - `cd web/modules/custom/skilld_default_content/content/`
     - `find . -type f -exec sed -i 's/\/user\\\/1/\/user\\\/5/g' {} +`
     - `find . -type f -exec sed -i 's/UUID_OF_ADMIN_USER/4bad48eb-ff5b-45b4-b30c-ecabff09591a' {} +`
6. Your default content should be created at build and it's author should be `skilld_default_content`


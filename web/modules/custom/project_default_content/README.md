# Skilld default content

## How to use ?

1. Enable module default_content. It should be already installed by composer.
2. Create content manually on site using UID1 admin user
3. Use `drush dcer` commands (brought by module) to export selected content :
```
drush dcer node <node id> --folder=modules/custom/project_default_content/content
drush dcer user <user id> --folder=modules/custom/project_default_content/content
drush dcer block_content <content id> --folder=modules/custom/project_default_content/content
drush dcer menu_link_content <link id> --folder=modules/custom/project_default_content/content
drush dcer taxonomy_term <term id> --folder=modules/custom/project_default_content/content
drush dcer file <file id> --folder=modules/custom/project_default_content/content
drush dcer media <media id> --folder=modules/custom/project_default_content/content
```
4. Find out what is UUID of admin user : `ls web/modules/custom/project_default_content/content/user`
     - `4bad48eb-ff5b-45b4-b30c-ecabff09591a` : UUID of default_content_author user
     - Another UUID should be listed here  : UUID of admin user
5. Delete json file of admin user : 
     - `rm web/modules/custom/project_default_content/content/user/UUID_OF_ADMIN_USER.json`
6. Use _sed_ commands to replace UID and UUID values of admin author in files of all exported content : 
      - `cd web/modules/custom/project_default_content/content/`
     - `find . -type f -exec sed -i 's/\/user\\\/1/\/user\\\/2/g' {} +`
     - `find . -type f -exec sed -i 's/UUID_OF_ADMIN_USER/4bad48eb-ff5b-45b4-b30c-ecabff09591a/g' {} +`
7. Exported default content will be created at build and it's author should be `default_content_author`


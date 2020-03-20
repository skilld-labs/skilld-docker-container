# Generic content importer

## How to use ?

1. Duplicate one of the exemple file from 'data' sub-directory
2. Update it's content with data to import
3. Use drush migrate commands to import selected migrate group :
```
drush migrate:import --group structural_content
drush migrate:import --group default_users
drush migrate:import --group test_content
drush migrate:import --group final_content
```

## Details

Make sure all files follow these rules strictly : 
- File name should be : $migrate_group-$entity-$bundle-$langcode-$some_unique_description.csv
    - For exemple : 
        - test_content-node-basic_page-en-some_unique_description.csv
        - structural_content-taxonomy_term-category-en-some_unique_description.csv
        - default_users-user-user-en-some_unique_description.csv
        - final_content-file-document-en-some_unique_description.csv
        - test_content-media-image-en-some_unique_description.csv
        - test_content-commerce_product_variation-category-en-some_unique_description.csv
- A header row should be present and list fields machine name existing in Drupal 
- Column delimiter should be ';'
- File should be .csv

Author of imported content will be "GCI user"

Several csv can belong to the same migrate group

Character set should be UTF-8

## How to import files ?

- Create a sub-directory named after the csv file : 
    - For exemple, _node-basic_page-en-test_content.csv_ should give :
        - data/node-basic_page-en-test_content/
- Place files in this directory
        - data/node-basic_page-en-test_content/something.jpg
        - data/node-basic_page-en-test_content/something_else.pdf
- Use these files by their name in your CSV


## How to import translations ?

- TBD

## Will content be duplicated if import is run multiple times ?

- Yes


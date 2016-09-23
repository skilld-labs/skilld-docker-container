ZEN'S CSS FILES
---------------

All of the files in this folder are files that are generated from the gulp tasks:
  - CSS generated from Sass
  - JavaScript generted from JS source
  - Twig files generated from Sass variables

In older versions of Zen, you could modify the CSS files and ignore the Sass files. But when we converted Zen to using component-based styles, it was clear that it is too hard to write CSS when Drupal makes it hard to change the markup.

You should:
- ignore these files
- modify the Sass files instead
- learn how to generate the CSS from the Sass. See your sub-theme's README.txt.

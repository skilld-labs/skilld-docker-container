BUILD A THEME WITH ZEN
----------------------

The base Zen theme is designed to be easily extended by its sub-themes. You
shouldn't modify any of the CSS or PHP files in the zen/ folder; but instead you
should create a sub-theme of zen which is located in a folder outside of the
root zen/ folder. The examples below assume zen and your sub-theme will be
installed in themes/, but any valid theme directory is acceptable (read
the sites/example.sites.php for more info.)

  Why? To learn why you shouldn't modify any of the files in the zen/ folder,
  see https://drupal.org/node/245802


*** IMPORTANT NOTE ***
*
* In Drupal 8, the theme system caches which template files and which theme
* functions should be called. This means that if you add a new theme,
* preprocess function to your [SUB-THEME].theme file or add a new template
* (.twig) file to your sub-theme, you will need to rebuild the "theme registry."
* See https://drupal.org/node/173880#theme-registry
*
* Drupal 8 also stores a cache of the data in .info.yml files. If you modify any
* lines in your sub-theme's .info.yml file, you MUST refresh Drupal 8's cache by
* simply visiting the Appearance page at admin/appearance.
*

There are 2 ways to create a Zen sub-theme:
1. An automated way using Drush
2. The manual way


CREATING A SUB-THEME WITH DRUSH
-------------------------------

 1. Install Drush. See https://github.com/drush-ops/drush for details.

 2. Ensure drush knows about the zen command.

    After you have installed Zen, Drush requires you to enable the Zen theme
    before using Zen's Drush commands. To make the drush zen command available
    to use, type:

      drush en zen -y

 3. See the options available to the drush zen command by typing:

      drush help zen

 4. Create a sub-theme by running the drush zen command with the desired
    parameters. IMPORTANT: The machine name of your sub-theme must start with an
    alphabetic character and can only contain lowercase letters, numbers and
    underscores. Type:

      drush zen [machine_name] [name] [options]

    Here are some examples:
    * Use:  drush zen "Amazing name"
      to create a sub-theme named "Amazing name" with a machine name
      (automatically determined) of amazing_name, using the default options.
    * Use:  drush zen zomg_amazing "Amazing name"
      to create a sub-theme named "Amazing name" with a machine name of
      zomg_amazing, using the default options.
    * Use:  drush zen "Amazing name" --path=sites/default/themes --description="So amazing."
      to create a sub-theme in the specified directory with a custom
      description.

 5. Check your website to see what themes are used as the default and admin
    themes. Type:

      drush status theme

 6. Set your website's default theme to be the new sub-theme. Type:

      drush vset theme_default zomg_amazing

      (Replace "zomg_amazing" with the actual machine name of your sub-theme.)

 7. Skip to the "ADDITIONAL SETUP" section below to finish creating your
    sub-theme.


CREATING A SUB-THEME MANUALLY
-------------------------------

 1. Setup the location for your new sub-theme.

    Copy the STARTERKIT folder out of the zen/ folder and rename it to be your
    new sub-theme. IMPORTANT: The name of your sub-theme must start with an
    alphabetic character and can only contain lowercase letters, numbers and
    underscores.

    For example, copy the themes/zen/STARTERKIT folder and rename it
    as themes/foo.

      Why? Each theme should reside in its own folder. To make it easier to
      upgrade Zen, sub-themes should reside in a folder separate from the base
      theme.

 2. Setup the basic information for your sub-theme.

    In your new sub-theme folder, rename the STARTERKIT.info.yml file to include
    the name of your new sub-theme. Then edit the .info.yml file by editing the
    name and description field.

    For example, rename the foo/STARTERKIT.info.yml file to foo/foo.info.yml.
    Edit the foo.info.yml file and change "name: Zen Sub-theme Starter Kit" to
    "name: Foo" and "description = Read..." to "description = A Zen sub-theme".

      Why? The .info.yml file describes the basic things about your theme: its
      name, description, template regions, and libraries. See the Drupal Theme
      Guide for more info: https://www.drupal.org/documentation/theme

    Remember to visit your site's Appearance page at admin/appearance to refresh
    Drupal 8's cache of .info.yml file data.

 3. Edit your sub-theme to use the proper function names.

    Edit the [SUB-THEME].theme and theme-settings.php files in your sub-theme's
    folder; replace ALL occurrences of "STARTERKIT" with the name of your
    sub-theme.

    For example, edit foo/foo.theme and foo/theme-settings.php and replace
    every occurrence of "STARTERKIT" with "foo".

    It is recommended to use a text editing application with search and
    "replace all" functionality.

 4. Set your website's default theme.

    Log in as an administrator on your Drupal site, go to the Appearance page at
    admin/appearance and click the "Enable and set default" link next to your
    new sub-theme.


ADDITIONAL SETUP
----------------

Your new Zen sub-theme uses Gulp.js as a task runner, so that it can do many
different tasks automatically:
 - Build your CSS from your Sass using libSass and node-sass.
 - Add vendor prefixes for the browsers you want to support using Autoprefixer.
 - Build a style guide of your components based on the KSS comments in your Sass
   source files.
 - Lint your Sass using sass-lint.
 - Lint your JavaScript using eslint.
 - Watch all of your files as you develop and re-build everything on the fly.

Set up your front-end development build tools:

 1. Install Node.js and npm, the Node.js package manager.

    Detailed instructions are available on the "npm quick start guide":
    https://github.com/kss-node/kss-node/wiki/npm-quick-start-guide

 2. The package.json file in your new sub-theme contains the versions of all the
    Node.js software you need. To install them run:

      npm install

 3. Install the gulp-cli tool globally. Normally, installing a Node.js globally
    is not recommended, which is why both Gulp and Grunt have created wrapper
    commands that will allow you to run "gulp" or "grunt" from anywhere, while
    using the local version of gulp or grunt that is installed in your project.
    To install gulp's global wrapper, run:

      npm install -g gulp-cli

 4. Set the URL used to access the Drupal website under development. Edit your
    gulpfile.js file and change the options.drupalURL setting:

      options.drupalURL = 'http://localhost';

 5. The default gulp task will build your CSS, build your style guide, and lint
    your Sass and JavaScript. To run the default gulp task, type:

      gulp

    To watch all your files as you develop, type:

      gulp watch

    To better understand the recommended development process for your Zen
    sub-theme, watch the Drupalcon presentation, "Style Guide Driven
    Development: All hail the robot overlords!"
    https://events.drupal.org/losangeles2015/sessions/style-guide-driven-development-all-hail-robot-overlords

Optional steps:

 6. Modify the box component styling.

    The sass/components/box/_box.scss file describes the styles of the "box"
    component. The code comments in that file reiterate the naming conventions
    use in our CSS and also describe how the nested Sass selectors compile into
    CSS.

    Try running "gulp watch", modifying the Sass, and then looking at how the
    style guide page at styleguide/section-components.html is automatically
    updated with the new CSS.

    Now try uncommenting the example ruleset under the "Drupal selectors"
    heading, recompiling the Sass, and then looking at your Drupal site (not the
    style guide) to see how the box component is applying to your sidebar
    blocks.

 7. Choose your preferred page layout method or grid system.

    By default your new sub-theme is using a responsive layout using Zen Grids.

    If you are more familiar with a different CSS layout method, such as Susy,
    Foundation, etc., you can replace the "layouts/layout-" lines in your
    styles.scss file with a line pointing at your choice of layout CSS file.

 8. Modify the markup in Zen core's template files.

    If you decide you want to modify any of the .tpl.php template files in the
    zen folder, copy them to your sub-theme's folder before making any changes.
    And then rebuild the theme registry.

    For example, copy zen/templates/page.tpl.php to foo/templates/page.tpl.php.

 9. Modify the markup in Drupal's search form.

    Copy the search-block-form.tpl.php template file from the modules/search/
    folder and place it in your sub-theme's template folder. And then rebuild
    the theme registry.

    You can find a full list of Drupal templates that you can override in the
    templates/README.txt file or https://drupal.org/node/190815

      Why? In Drupal 8 theming, if you want to modify a template included by a
      module, you should copy the template file from the classy theme's
      directory to your sub-theme's template directory and then rebuild the
      theme registry. See the Drupal 8 Theme Guide for more info:
      https://drupal.org/node/173880

 10. Further extend your sub-theme.

    Discover further ways to extend your sub-theme by reading Zen's
    documentation online at:
      https://drupal.org/documentation/theme/zen
    and Drupal 8's Theme Guide online at:
      https://drupal.org/theme-guide/8

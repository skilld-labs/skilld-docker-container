## Make backup from current state
mysql_dump_name = $(COMPOSE_PROJECT_NAME).sql
files_dir = web/sites/default/files
datestamp=$(shell echo `date +'%Y-%m-%d'`)
backup_name = $(COMPOSE_PROJECT_NAME)-$(datestamp).tar.gz

backup:
	rm -f $(backup_name)
	$(call php, drush sql-dump --database=default --result-file=../$(mysql_dump_name) --structure-tables-list=cachetags,cache_*,flood,sessions,watchdog)
	tar -czvf $(backup_name) --exclude=$(files_dir)/translations --exclude=$(files_dir)/js --exclude=$(files_dir)/css --exclude=$(files_dir)/styles --exclude=$(files_dir)/php $(files_dir) $(mysql_dump_name)
	rm $(mysql_dump_name)

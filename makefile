include auto-generated-dependencies.d

#vpath %.c src
#vpath %.h include
auto-generated-dependencies.d :
	@echo 'Generating dependencies'
	@sh generate_dependencies.sh

#@echo 1 % $% The filename element of an archive member specification
#@echo 2 @ $@ The filename representing the target
#@echo 3 ? $? The names of all prerequisites that are newer than the target, separated by spaces.
#@echo 4 ^ $^ The filenames of all the prerequisites, separated by spaces. This list has duplicate filenames removed since for most uses, such as compiling, copying, etc., duplicates are not wanted
#@echo 5 + $+ Similar to $^ , this is the names of all the prerequisites separated by spaces, except that $+ includes duplicates. This variable was created for specific situations such as arguments to linkers where duplicate values have meaning.
#@echo 6 $* The stem of the target filename. A stem is typically a filename without its suffix.  (We’ll discuss how stems are computed later in the section “Pattern Rules.”) Its use outside of pattern rules is discouraged.
#@echo 7 < $< The filename of the first prerequisite

#A static pattern rule is one that applies only to a specific list of targets.
#$(OBJECTS): %.o: %c
#		$(CC) -c $(CFLAGS) $< -o $@
#The only difference between this rule and an ordinary pattern rule is the initial
#$(OBJECTS): specification. This limits the rule to the files listed in the $(OBJECTS) vari-
#able

.PHONY: clean
clean :
	@rm -f js/*.js
	@rm auto-generated-dependencies.d


.PHONY: help
help:
	$(MAKE) --print-data-base --question |
	$(AWK) '/^[^.%][-A-Za-z0-9_]*:/
		{ print substr($$1, 1, length($$1)-1) }' |
	$(SORT) |
	$(PR) --omit-pagination --width=80 --columns=4

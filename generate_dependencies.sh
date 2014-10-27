output=../auto-generated-dependencies.d
cd src
suffix=".*"

echo .PHONY: all >> $output
for f in *.js *.coffee
do
  echo all : js/${f%$suffix}.js >> $output
done

for f in *.coffee
do
  echo js/${f%$suffix}.js : src/$f >> $output
done

echo "" >> $output
echo js/%.js : src/%.coffee >> $output
echo "\t@echo \$@" >> $output
echo "\t@coffee --compile $<" >> $output
echo "\t@mv src/\$*.js js/" >> $output
echo "" >> $output

for f in *.js
do
  echo js/$f : src/$f >> $output
  echo "\t@cp src/$f js/$f" >> $output
  echo "\t@echo $f" >> $output
  echo "" >> $output
done


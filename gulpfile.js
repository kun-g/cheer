var gulp = require('gulp');

var coffee = require('gulp-coffee');
var uglify = require('gulp-uglify');
var mocha = require('gulp-mocha');
var coffeeLint = require('gulp-coffeelint');
var cache = require('gulp-cached');
var cover = require('gulp-coverage');
//var tar = require('gulp-tar');
//var gzip = require('gulp-gzip');
//var s3 = require('gulp-gzip');
//var gif = require('gulp-if');
//var footer = require('gulp-footer');

var paths = {
  coffees: ['src/*.coffee'],
  scripts: ['js/*.js'],
  tests: ['test/*.js']
};

gulp.task('mocha', function () {
  gulp.src(paths.tests, { read: false })
    .pipe(mocha({
      reporter: 'nyan',
    }))
    .on('error', console.log);
});

gulp.task('coverage', function () {
  gulp.src(paths.tests, { read: false })
    .pipe(cover.instrument({
      pattern: ['js/*']
    }))
    .pipe(mocha({
    }))
    .pipe(cover.report({
      outFile: 'coverage.html'
    }))
    .on('error', function () {});
});

gulp.task('compile', function () {
  return gulp.src(paths.coffees)
    .pipe(cache('compile'))
    .pipe(coffee())
    //.pipe(uglify())
    .pipe(gulp.dest('js'))
    .on('error', console.log);
});

gulp.task('watch', function () {
  gulp.watch(paths.coffees, ['lint', 'compile']);
  gulp.watch(paths.tests, ['mocha']);
});

gulp.task('lint', function () {
  return gulp.src(paths.coffees)
    .pipe(cache('lint'))
    .pipe(coffeeLint(null, {max_line_length: {level: 'error', value: 180}}))
    .pipe(coffeeLint.reporter());
});
/*
var gulp = require('gulp');
var changed = require('gulp-changed');
var ngmin = require('gulp-ngmin'); // just as an example

var SRC = 'src/*.js';
var DEST = 'dist';

gulp.task('default', function () {
gulp.src(SRC)
.pipe(changed(DEST))
    // ngmin will only get the files that
    // changed since the last time it was run
    .pipe(ngmin())
    .pipe(gulp.dest(DEST));
    });
 */
// npm install gulp yargs gulp-if gulp-uglify
// var args   = require('yargs').argv;
// var gulp   = require('gulp');
// var gulpif = require('gulp-if');
// var uglify = require('gulp-uglify');
//
// var isProduction = args.type === 'production';
//
// gulp.task('scripts', function() {
//   return gulp.src('**/*.js')
//       .pipe(gulpif(isProduction, uglify())) // only minify if production
//           .pipe(gulp.dest('dist'));
//           });
//gulp scripts --type production

gulp.task('default', ['watch']);

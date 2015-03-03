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
  js: ['src/*.js'],
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

gulp.task('js', function () {
  return gulp.src(paths.js)
    .pipe(cache('js'))
    //.pipe(uglify())
    .pipe(gulp.dest('js'))
    .on('error', console.log);
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
  gulp.watch(paths.js, ['js']);
});

gulp.task('lint', function () {
  return gulp.src(paths.coffees)
    .pipe(cache('lint'))
    .pipe(coffeeLint(null, {max_line_length: {level: 'error', value: 180}}))
    .pipe(coffeeLint.reporter());
});

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

var changed = require('gulp-changed');
var through = require('through2');
var path = require('path');
var gutil = require('gulp-util');
var fs = require('fs');

var SRC = 'src/*.js';
var DEST = 'dist';
var exec = require('child_process').exec;

function execCallback(cb) {
	return function (error, out, err) {
		if (error) {
			console.log(error.message);
		} else if (err)  {
			console.log(err);
		} else {
			cb(err, out);
		}
	}
};
jsbcc = function (src, dest, opts) {
	opts = opts || {};

	if (!dest) {
		throw new gutil.PluginError('JSBCC', '`dest` required');
	}

	return through.obj(function (file, enc, cb) {
    console.log(enc);
		if (file.isNull()) {
			this.push(file);
			return cb();
		}

        var jsPath = path.join(src, file.relative);
        var jscPath = path.join(dest, file.relative)+'c';
        var jsbccPath = '/home/kun/develop/cocos2d-js-v3.0-rc2/tools/cocos2d-console/plugins/plugin_jscompile/bin/jsbcc';
        var cmd = '';
        cmd += jsbccPath + ' ';
        cmd += jsPath + ' ' + jscPath;
        console.log(cmd);
        exec(cmd, execCallback(function (err, result) {
            this.push(file);
            cb();
        }.bind(this)));
	});
};

gulp.task('test', function () {
    gulp.src(SRC)
    .pipe(changed(DEST, {extension: 'js'}))
    // ngmin will only get the files that
    // changed since the last time it was run
    .pipe(jsbcc('js', 'jsbccED'))
    .pipe(gulp.dest(DEST));
  }
);


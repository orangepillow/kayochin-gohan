gulp = require 'gulp'
bower = require 'gulp-bower-files'
flatten = require 'gulp-flatten'
uglify = require 'gulp-uglify'

gulp.task 'bower', ->
  bower()
    .pipe uglify()
    .pipe flatten()
    .pipe (gulp.dest 'lib')

gulp.task 'scripts', ->
  gulp.src('lib/*.js')
    .pipe (gulp.dest 'app/public/js')

gulp.task 'css', ->
  gulp.src('lib/*.css')
    .pipe (gulp.dest 'app/public/css')

gulp.task('default', ['bower', 'scripts', 'css']);

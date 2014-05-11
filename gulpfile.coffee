gulp = require 'gulp'
bower = require 'gulp-bower-files'
flatten = require 'gulp-flatten'
sass = require 'gulp-sass'
watch = require 'gulp-watch'
concat = require 'gulp-concat'
uglify = require 'gulp-uglify'
livereload = require 'gulp-livereload'
server = (require 'tiny-lr')()

gulp.task 'bower', ->
  bower()
    .pipe uglify()
    .pipe flatten()
    .pipe (gulp.dest 'lib')

gulp.task 'scripts', ->
  gulp.src('lib/*.js')
    .pipe (gulp.dest 'app/public/js')

gulp.task 'sass', ->
  gulp.src('app/assets/stylesheets/*.scss')
    .pipe sass()
    .pipe (gulp.dest './lib/')
    .pipe (livereload server)

gulp.task 'css', ->
  gulp.src('lib/*.css')
    .pipe concat('all.css')
    .pipe (gulp.dest 'app/public/css')
    .pipe (livereload server)

gulp.task 'watch', ->
  server.listen 35729, (err) ->
    if err
      console.log err
      return
    gulp.watch 'app/views/*.slim'
    gulp.watch 'app/assets/stylesheets/*.scss', ['sass', 'css']

gulp.task('default', ['bower', 'scripts', 'sass', 'css']);

gulp.task('develop', ['bower', 'scripts', 'sass', 'css', 'watch']);


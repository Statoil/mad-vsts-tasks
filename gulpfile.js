const gulp = require('gulp');
const gutil = require('gulp-util');
const childProcess = require('child_process');
const process = require('process');

function make(target, cb) {
  const cl = (`node make.js ${target} ${process.argv.slice(3).join(' ')}`).trim();
  console.log('------------------------------------------------------------');
  console.log(`> ${cl}`);
  console.log('------------------------------------------------------------');
  try {
    childProcess.execSync(cl, { cwd: __dirname, stdio: 'inherit' });
  } catch (err) {
    const msg = err.output ? err.output.toString() : err.message;
    console.error(msg);
    cb(new gutil.PluginError(msg));
    return false;
  }

  return true;
}

gulp.task('build', (cb) => {
  make('build', cb);
});

gulp.task('default', ['build']);

gulp.task('package', (cb) => {
  const publish = process.argv.filter(arg => arg === '--server').length > 0;
  make('build', cb)
    && make('package', cb)
    && publish
    && make('publish', cb);
});

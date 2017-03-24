const argv = require('minimist')(process.argv.slice(2));

let {
  configuration = 'DEBUG',
} = argv;

configuration = configuration.toUpperCase();

const env = process.env;

process.stdout.write(`Collapsing environment variables for the ${configuration} build\n`);

Object.keys(env).forEach((key) => {
  const prefix = `${configuration}_`;

  if (key.startsWith(prefix)) {
    const envVar = env[key];
    const newKey = key.replace(`${configuration}_`, '');
    process.stdout.write(`##vso[task.setvariable variable=${newKey};]${envVar}\n`);
  }
});

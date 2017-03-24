
const env = process.env;
const configuration = env.INPUT_CONFIGURATIONNAME;

process.stdout.write(`Collapsing environment variables for the ${configuration} build\n`);

Object.keys(env).forEach((key) => {
  const prefix = `${configuration}_`.toUpperCase();

  process.stdout.write(`testing environment variable '${key}' against prefix ${prefix} \n`);

  if (key.startsWith(prefix)) {
    const envVar = env[key];
    const newKey = key.replace(`${configuration}_`, '');
    process.stdout.write(`##vso[task.setvariable variable=${newKey};]${envVar}\n`);
  }
});

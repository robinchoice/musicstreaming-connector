import { run } from './cli';

const code = await run(process.argv.slice(2), {
  env: process.env,
  out: (text) => console.log(text),
  err: (text) => console.error(text),
  stdin: () => Bun.stdin.text(),
});
process.exit(code);

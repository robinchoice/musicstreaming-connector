// Compiles the CLI into one file named like the app (AGENTS.md, „CLI“), with
// the live URL baked in. Further arguments go to bun build, such as --target=bun-darwin-arm64.
import { $ } from 'bun';
import { SLUG } from './src/config';

const url = process.env.APP_URL || 'https://songgate.app';
await $`bun build src/main.ts --compile --minify --outfile build/${SLUG} --define process.env.CLI_URL=${JSON.stringify(url)} ${process.argv.slice(2)}`;

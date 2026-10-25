// The slug of the app (Android org.pleasance.songgate). The CLI's file carries it.
export const SLUG = 'songgate';

// build.ts bakes in the URL of the live app, from source it's the default address
export const DEFAULT_URL = process.env.CLI_URL || 'https://songgate.app';

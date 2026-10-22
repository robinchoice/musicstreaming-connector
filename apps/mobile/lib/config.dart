const appName = 'Songgate';
// The same as LIVE in packages/shared: true once Songgate is live as 1.0.
// From then on the bug button waits for the test mode switch in the settings.
const live = false;
const appBand = (from: 3.85, to: 4.55);
const apiUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://localhost:3000',
);

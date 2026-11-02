import type { HandleClientError } from '@sveltejs/kit/hooks';
import * as Sentry from '@sentry/browser';
import { PUBLIC_SENTRY_DSN, PUBLIC_SENTRY_ENVIRONMENT } from '$app/env/public';

Sentry.init({
  dsn: PUBLIC_SENTRY_DSN,
  environment: PUBLIC_SENTRY_ENVIRONMENT || 'production',
  dataCollection: {
    userInfo: false,
    cookies: false,
    httpHeaders: false,
    httpBodies: [],
    urlQueryParams: false,
    graphQL: { document: false, variables: false },
    genAI: { inputs: false, outputs: false },
    databaseQueryData: false,
    queues: false,
    stackFrameVariables: false,
    frameContextLines: 0,
  },
  maxBreadcrumbs: 0,
  tracesSampleRate: 0,
  sendClientReports: false,
  integrations: (defaults) => defaults.filter((integration) =>
    !['BrowserSession', 'Breadcrumbs', 'HttpContext'].includes(integration.name)),
  beforeSend(event) {
    delete event.request
    delete event.user
    return event
  },
});

export const handleError: HandleClientError = ({ error }) => {
  Sentry.captureException(error);
};

// iOS opens share pages and invites in the app when it is installed (Universal Links).
// Needs the Associated Domains entitlement applinks:songgate.app in the app.
export const GET = () =>
  Response.json({
    applinks: {
      details: [{ appIDs: ['T2F442364K.org.musiclink.prototype'], components: [{ '/': '/s/*' }, { '/': '/f/*' }] }],
    },
  });

## 0.4.0 [2026-08-07
- Add the dashboard
- 

## 0.3.0 [2026-06-24]
- Add user agent parser for browser, engine and operating system detection
- Add bot detection with a configurable `track_bots` option to exclude crawler traffic (bot tracking is disabled by default in production)
- Record browser, engine and operating system demographics automatically for new visits
- Refactor tracking into a `ControllerDelegate`, with cookie handling consolidated in a new `CookieManager`
- Generate a fresh tracking token on consent so visitors sharing an IP and user agent are no longer linked
- Ensure analytics failures can never interrupt the host application's requests
- Harden referrer and exit-page URL redaction against malformed input, with a configurable length limit
- Validate the cache store used for anonymity sets, warning or disabling when it is unsupported
- Renew cookies on every request
- Expand unit and integration test coverage

## 0.2.0 [2026-06-13]
- Various security fixes
- Change defaults to be more privacy focused
- Fix views not being associated with visits
- Change skadi_tag default to :inline
- Add rate limiting
- Add minimum supported versions for Ruby (3.3) and Rails (7.2)
- Add additional details to readme

## 0.1.0 [2026-06-07]
- Scaffold gem
- Add tracking controller
- Add tracking front-end script

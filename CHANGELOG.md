## 0.4.0.beta.2 [2026-08-27]
- Remove server host from referrer and exit page URLs
- Update dashboard datasets to allow belongs_to joining, and remove chart level filters

## 0.4.0.beta.1 [2026-08-19]
- Add the dashboard
- Breaking: single consent and opt-out changed to more granular consent
- Breaking: user_method configuration option changed to user_controller_method
- DB: skadi_views.referrer removed
- DB: skadi_visits.cookies_enabled added to track cookie consent for visits
- DB: added additional indexes
- DB: added skadi_dashboards table
- Tracking script: fix requests not being queued
- Tracking script: fix FCP not being recorded in Chrome
- Tracking script: LCP now sent on page_hide instead of after a delay
- Refactor asset controller to use ActionController::Metal
- Fix skadi_tag crashing without a view
- Development: migrated from standard to rubocop-rails-omakase plus customisations
- Development: added biome and svelte-check to the front end

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

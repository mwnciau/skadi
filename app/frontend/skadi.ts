// Define these non-constant variables first so the minifier can group all the consts together
let demographics: SkadiDemographic[] = [];
let events: SkadiEvent[] = [];
let consent: Consent = {};
let largestContentfulPaint: number = -1;
let requestTimeout: number|null = null;
let departureUrl: string|null = null;
let useDepartureUrl: boolean = false;

// The minifier doesn't automatically shorten these variables, so we make a local variable to force it to
const _window = window;
const _performance = performance;
const _document = document;

// Reuse these strings to save space
const contentfulPaint = "-contentful-paint";
const firstContentfulPaintId = `first${contentfulPaint}`;
const largestContentfulPaintId = `largest${contentfulPaint}`;

type SkadiOptions = {
  // The URI for the current page to be appended to view-specific demographic data
  pageUri: string;
  // The Rails authenticity token
  csrf: string;
  // The URL to send data to
  endpoint: string;
  // The view's view_token
  view: string;
  // The visit's visit_token, if available
  visit?: string;
}

type SkadiDemographic = {
  uri?: string;
  name: string;
  value: string;
}

type SkadiEvent = {
  name: string;
  properties: Record<string, unknown>;
}

type Consent = {
  cookies?: boolean;
  doNotTrack?: boolean;
}

const options: SkadiOptions = {
  ..._document.currentScript.dataset,
}

const queueRequest = () => {
  requestTimeout = setTimeout(sendRequest, 500);
}

const sendRequest = () => {
  if (requestTimeout !== null) {
    clearTimeout(requestTimeout);
    requestTimeout = null;
  }

  const result = navigator.sendBeacon(options.endpoint, new Blob([JSON.stringify({
    authenticity_token: options.csrf,
    view: options.view,
    demographics,
    events,
    consent,
    ...(useDepartureUrl && {departureUrl})
  })], {type: "application/json"}));

  // If the beacon was succesfully sent
  if (result) {
    demographics = [];
    events = [];
    consent = {};
  }
}

const bucketise = (value: number, buckets: number[4]) => {
  // Zero or negative values should not be appearing so are likely an edge-case browser behaviour we can discard
  if (value <= 0) {
    return;
  }

  if (value < buckets[0]) {
    return `< ${buckets[0]}ms`;
  }

  for (let i = 1; i < buckets.length; i++) {
    if (value <= buckets[i]) {
      return `${buckets[i - 1]}ms to ${buckets[i]}ms`;
    }
  }

  return `> ${buckets[3]}ms`;
};

const addDemographic = (name: string, value: string|boolean, viewDemographic: boolean = true) => {
  if (value === null) {
    return;
  }

  let demographic = {name, value: value.toString()};

  if (viewDemographic) {
    demographic.uri = options.pageUri;
  }

  demographics.push(demographic);
};

const populatePerformanceDemographics = () => {
  let navigationTiming = _performance.getEntriesByType("navigation")?.[0];
  if (navigationTiming) {
    // Server response time
    addDemographic(
      "time-to-first-byte",
      bucketise(navigationTiming.responseStart - navigationTiming.requestStart, [200, 400, 800, 1500]),
    );

    // Network download time for the HTML page
    addDemographic(
      "time-to-download",
      bucketise(navigationTiming.responseEnd - navigationTiming.responseStart, [50, 150, 400, 1000]),
    );

    // Time it took to parse the DOM and run blocking scripts
    addDemographic(
      "time-to-process-dom",
      bucketise(navigationTiming.domInteractive - navigationTiming.responseEnd, [100, 300, 600, 1500]),
    );

    // Total time from request start to the window on load event fires
    addDemographic(
      "total-load-time",
      bucketise(navigationTiming.loadEventEnd - navigationTiming.startTime, [2000, 3500, 6000, 10000]),
    );
  }

  let paintTiming = _performance.getEntriesByName(firstContentfulPaintId)?.[0];
  if (paintTiming) {
    addDemographic(
      firstContentfulPaintId,
      bucketise(paintTiming.startTime, [1000, 1800, 3000, 4500]),
    );
  }
};

// The largest contentful paint is triggered multiple times during a page load, so we need to use the Observer API to keep track of each LCP as the page loads.
new PerformanceObserver((entryList) => {
  let entries = entryList.getEntries();
  let lastEntry = entries[entries.length - 1];
  largestContentfulPaint = lastEntry.startTime;
}).observe({ type: largestContentfulPaintId, buffered: true });

const mediaMatches = (query: string): boolean => {
  return _window.matchMedia(query).matches;
}

const populateVisitDemographics = () => {
  addDemographic("timezone", Intl.DateTimeFormat().resolvedOptions().timeZone, false);
  addDemographic("locale", Intl.NumberFormat().resolvedOptions().locale, false);
  addDemographic("screen-size", `${_window.innerWidth}x${_window.innerHeight}`, false);
  addDemographic("input-device", mediaMatches('(pointer: fine)') ? "mouse" : "touch", false);
}

_window.addEventListener('load', () => {
  // Send an initial ping once the page loads with the basic performance demographics
  // Ensure this runs after the load event has finished to ensure the total load time is accurate
  setTimeout(() => {
    populatePerformanceDemographics();
    if (options.visit) {
      populateVisitDemographics();
    }
    sendRequest();
  }, 0)
})

// Track clicks to detect when the user leaves the page
_document.addEventListener('click', (event: MouseEvent) => {
  let link = event.target.closest('a');

  if (link && link.href) {
    let isNewTab = link.target === '_blank' || event.ctrlKey || event.metaKey;

    if (!isNewTab) {
      departureUrl = link.href;
    }
  }
});

_window.addEventListener('pagehide', () => {
  // Flags that the page is unloading so the beacon send in bisi
  useDepartureUrl = true;
})

// Trigger sending the data when the user unloads the page
_window.addEventListener('visibilitychange', () => {
  sendRequest();
});

setTimeout(() => {
  addDemographic(
    largestContentfulPaintId,
    bucketise(largestContentfulPaint, [1500, 2500, 4000, 6000]),
  );
}, 6000)


_window.skadi = {
  event: (name: string, properties: Record<string, unknown>) => {
    events.push({name, properties});
    queueRequest();
  },
  demographic: (name: string, value: string, isPageSpecific: boolean = false) => {
    addDemographic(name, value, isPageSpecific);
    queueRequest();
  },
  setCookieConsent: (newValue: boolean) => {
    consent.cookies = newValue;
    sendRequest();
  },
  setTrackingOptOut: (newValue: boolean) => {
    consent.doNotTrack = newValue;
    sendRequest();
  },
};

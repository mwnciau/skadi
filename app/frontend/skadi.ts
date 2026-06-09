// Define these non-constant variables first so the minifier can group all the consts together
let demographics: SkadiDemographic[] = [];
let events: SkadiEvent[] = [];
let consent: Consent = {};
let largestContentfulPaint: number = -1;
let requestTimeout: number|null = null;
let exitPage: string|null = null;
let useExitPage: boolean = false;

// The minifier doesn't automatically shorten these variables, so we make a local variable to force it to
const _window = window;
const _document = document;

// Reuse these strings to save space
const contentfulPaint = "-contentful-paint";
const firstContentfulPaintId = `first${contentfulPaint}`;
const largestContentfulPaintId = `largest${contentfulPaint}`;

type SkadiOptions = {
  // The URI for the current page to be appended to view-specific demographic data
  uri: string;
  // The URL to send data to
  endpoint: string;
  // The view's view_token
  view: string;
  // Whether to send visit demographics
  visit?: "1" | null;
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
  id?: boolean;
  optOut?: boolean;
}

const options: SkadiOptions = {
  ..._document.currentScript.dataset as SkadiOptions,
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
    view: options.view,
    demographics,
    events,
    consent,
    ...(useExitPage && {exit_page: exitPage})
  })], {type: "application/json"}));

  // If the beacon was succesfully sent
  if (result) {
    demographics = [];
    events = [];
    consent = {};

    // Note: no need to set useExitPage here as it is only set as the page is being unloaded.
  }
}

const bucketise = (value: number, buckets: [number, number, number, number]): string | null => {
  // Zero or negative values should not be appearing so are likely an edge-case browser behaviour we can discard
  if (value <= 0) {
    return null;
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

const addDemographic = (name: string, value: string | boolean | null, viewDemographic: boolean = false) => {
  if (value === null) {
    return;
  }

  let demographic: SkadiDemographic = {name, value: value.toString()};

  if (viewDemographic) {
    demographic.uri = options.uri;
  }

  demographics.push(demographic);
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

_window.addEventListener('load', () => {
  let paintTiming = performance.getEntriesByName(firstContentfulPaintId)?.[0];
  if (paintTiming) {
    addDemographic(
      firstContentfulPaintId,
      bucketise(paintTiming.startTime, [1000, 1800, 3000, 4500]),
      true
    );
  }

  if (options.visit === "1") {
    addDemographic("timezone", Intl.DateTimeFormat().resolvedOptions().timeZone);
    addDemographic("locale", Intl.NumberFormat().resolvedOptions().locale);
    addDemographic("screen-size", `${_window.innerWidth}x${_window.innerHeight}`);
    addDemographic("input-device", mediaMatches('(pointer: fine)') ? "mouse" : "touch");
  }

  queueRequest();
})

setTimeout(() => {
  addDemographic(
    largestContentfulPaintId,
    bucketise(largestContentfulPaint, [1500, 2500, 4000, 6000]),
    true,
  );
  queueRequest();
}, 6000);

// Track clicks to detect when the user leaves the page
_document.addEventListener('click', (event: MouseEvent) => {
  let link = event.target?.closest('a');

  if (link && link.href) {
    let isNewTab = link.target === '_blank' || event.ctrlKey || event.metaKey;

    if (!isNewTab) {
      exitPage = link.href;
    }
  }
});

_window.addEventListener('pagehide', () => {
  // Flags that the page is unloading so the beacon sends the exit page
  useExitPage = true;
  sendRequest();
})

_window.addEventListener('visibilitychange', () => {
  // Ensure a beacon is sent immediately if the user switches
  if (requestTimeout !== null) {
    sendRequest();
  }
});


_window.skadi = {
  event: (name: string, properties: Record<string, unknown> = {}) => {
    events.push({name, properties});
    queueRequest();
  },
  demographic: (name: string, value: string, isPageSpecific: boolean = false) => {
    addDemographic(name, value, isPageSpecific);
    queueRequest();
  },
  setCookieConsent: (newValue: boolean) => {
    consent.id = newValue;
    sendRequest();
  },
  setTrackingOptOut: (newValue: boolean) => {
    consent.optOut = newValue;
    sendRequest();
  },
};

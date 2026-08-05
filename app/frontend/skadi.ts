// Define these non-constant variables first so the minifier can group all the consts together
let demographics: SkadiDemographic[] = [];
let events: SkadiEvent[] = [];
let largestContentfulPaint: number = -1;
let requestTimeout: number|undefined;
let exitPage: string|undefined;
let useExitPage: boolean = false;

type Consent = {
  cookie?: boolean;
  anonymity_set?: boolean;
  user?: boolean;
}

interface Window {
  skadi?: {
    event: (name: string, properties: Record<string, unknown>) => void;
    demographic: (name: string, value: string, isPageSpecific: boolean) => void;
    consent: (newConsent: Consent) => void;
  };
}

let consent: Consent = {};

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

const options: SkadiOptions = {
  // @ts-ignore currentScript is not null because we control how this script is included
  ..._document.currentScript.dataset as SkadiOptions,
}

const queueRequest = () => {
  requestTimeout ??= setTimeout(sendRequest, 500);
}

const sendRequest = () => {
  if (requestTimeout) {
    clearTimeout(requestTimeout);
    requestTimeout = 0;
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

new PerformanceObserver((entryList, observer) => {
  let paintTiming = entryList.getEntriesByName(firstContentfulPaintId)[0];

  if (paintTiming) {
    addDemographic(
      firstContentfulPaintId,
      bucketise(paintTiming.startTime, [1000, 1800, 3000, 4500]),
      true
    );
    observer.disconnect();
  }
}).observe({ type: "paint", buffered: true });

_window.addEventListener('load', () => {
  if (options.visit === "1") {
    addDemographic("timezone", Intl.DateTimeFormat().resolvedOptions().timeZone);
    addDemographic("locale", Intl.NumberFormat().resolvedOptions().locale);
    addDemographic("screen-size", `${_window.innerWidth}x${_window.innerHeight}`);
    addDemographic("input-device", _window.matchMedia('(pointer: fine)').matches ? "mouse" : "touch");
  }

  // Always send a beacon on page load to send the FCP and also verify the view
  queueRequest();
});

// Track clicks to detect when the user leaves the page
_document.addEventListener('click', (event: MouseEvent) => {
  let link = (event.target as Element | null)?.closest('a');

  if (link && link.href) {
    let isNewTab = link.target === '_blank' || event.ctrlKey || event.metaKey;

    if (!isNewTab) {
      exitPage = link.href;
    }
  }
});

_window.addEventListener('pagehide', () => {
  addDemographic(
    largestContentfulPaintId,
    bucketise(largestContentfulPaint, [1500, 2500, 4000, 6000]),
    true,
  );

  // Flags that the page is unloading so the beacon sends the exit page
  useExitPage = true;
  sendRequest();
});

_window.addEventListener('visibilitychange', () => {
  // Ensure any queued beacon is sent immediately if the user switches tab
  if (requestTimeout) {
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
  consent: (newConsent: Consent) => {
    consent = newConsent;
    sendRequest();
  },
};

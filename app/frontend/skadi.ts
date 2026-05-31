// The file that does the tracking

const scriptElement = document.currentScript;

type SkadiOptions = {
  // The URI for the current page to be appended to view-specific demographic data
  pageUri: string;
  // The Rails authenticity token
  csrf: string;
  // The URL to send tracking events to
  endpoint: string;
  // The view's view_token
  view: string;
  // The visit's visit_token, if available
  visit?: string;
}

type Demographic = {
  uri?: string;
  name: string;
  value: string;
}

type ResponseData = {
  visit?: string,
  view?: string,
  demographics?: Demographic[],
  events?: [],
}

const options: SkadiOptions = {
  ...scriptElement.dataset,
}

let demographics: Demographic[] = [];
let largestContentfulPaint: number = -1;

const sendRequest = () => {
  const request = {
    view: options.view,
    visit: options.visit,
    demographics,
  }
  //navigator.sendBeacon(options.endpoint, JSON.stringify(data));

  const el = document.createElement("PRE");
  el.innerText = JSON.stringify(request, null, 2);
  document.body.appendChild(el);
}

// The largest contentful paint is triggered multiple times as a the page load, so we need to use the Observer API to keep track of each LCP as the page loads.
new PerformanceObserver((entryList) => {
  const entries = entryList.getEntries();
  const lastEntry = entries[entries.length - 1];
  largestContentfulPaint = lastEntry.startTime;
}).observe({ type: "largest-contentful-paint", buffered: true });

const bucketise = (value: number, buckets: number[], unit: string = "") => {
  // Zero or negative values should not be appearing so are likely an edge-case browser behaviour we can discard
  if (value <= 0) {
    return "n/a";
  }

  if (value < buckets[0]) {
    return `< ${buckets[0]}${unit}`;
  }

  for (let i = 1; i < buckets.length; i++) {
    if (value <= buckets[i]) {
      return `${buckets[i - 1]}${unit} to ${buckets[i]}${unit}`;
    }
  }

  return `> ${buckets[buckets.length - 1]}${unit}`;
};

const addDemographic = (name: string, value: string, viewDemographic: boolean = true) => {
  const demographic = {name, value};

  if (viewDemographic) {
    demographic.uri = options.pageUri;
  }

  demographics.push(demographic);
};

const populatePerformanceDemographics = () => {
  const navigationTiming = performance.getEntriesByType("navigation")?.[0];
  if (navigationTiming) {
    // Server response time
    addDemographic(
      "time_to_first_byte",
      bucketise(navigationTiming.responseStart - navigationTiming.requestStart, [200, 400, 800, 1500], "ms"),
    );

    // Network download time for the HTML page
    addDemographic(
      "time_to_download",
      bucketise(navigationTiming.responseEnd - navigationTiming.responseStart, [50, 150, 400, 1000], "ms"),
    );

    // Time it took to parse the DOM and run blocking scripts
    addDemographic(
      "time_to_process_dom",
      bucketise(navigationTiming.domInteractive - navigationTiming.responseEnd, [100, 300, 600, 1500], "ms"),
    );

    // Total time from request start to the window on load event fires
    addDemographic(
      "total_load_time",
      bucketise(navigationTiming.loadEventEnd - navigationTiming.startTime, [2000, 3500, 6000, 10000], "ms"),
    );
  }

  const paintTiming = performance.getEntriesByName("first-contentful-paint")?.[0];
  if (paintTiming) {
    addDemographic(
      "first_contentful_paint",
      bucketise(paintTiming.startTime, [1000, 1800, 3000, 4500], "ms"),
    );
  }
};

window.addEventListener('load', () => {
  // Send an initial ping once the page loads with the basic performance demographics
  // Ensure this runs after the load event has finished to ensure the total load time is accurate
  setTimeout(() => {
    populatePerformanceDemographics();
    sendRequest();
  }, 0)
})

// Trigger sending the data when the user unloads the page
window.addEventListener('visibilitychange', () => {
  addDemographic(
    "largest_contentful_paint",
    bucketise(largestContentfulPaint, [1500, 2500, 4000, 6000], "ms"),
  );
});

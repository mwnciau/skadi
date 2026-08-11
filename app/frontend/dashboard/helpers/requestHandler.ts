import type {
  ChartConfig,
  ChartFilters,
  DashboardConfig,
  RawChartResponseData,
  RawResponse,
  TabFilters
} from "../../types";

const callingScript = document.querySelector<HTMLElement>("[data-dashboard-config]");
const fetchDataPath = callingScript?.dataset?.fetchDataPath as string;
const updateDashboardPath = callingScript?.dataset?.updateDashboardPath as string;

const csrfParam = (document.querySelector("meta[name=csrf-param]") as HTMLMetaElement)?.content;
const csrfToken = (document.querySelector("meta[name=csrf-token]") as HTMLMetaElement)?.content;

const handleResponseError = (response: Response) => {
  return response.text().then((text) => {
    let body = null;
    if (text) {
      try {
        body = JSON.parse(text);
      } catch {}
    }

    if (!response.ok) {
      throw new Error(body?.error ?? `Request failed with status ${response.status}\n${text}`);
    }

    return body;
  });
};

export const fetchChartData = (chart: string | ChartConfig, tabFilters: TabFilters, chartFilters: ChartFilters): Promise<RawResponse> => {
  const queryVars: Record<string, unknown> = {
    [csrfParam]: csrfToken,
  };

  if (tabFilters.date_from) {
    queryVars.date_from = tabFilters.date_from;
  }
  if (tabFilters.date_to) {
    queryVars.date_to = tabFilters.date_to;
  }
  if (chartFilters.page) {
    queryVars.page = chartFilters.page;
  }
  if (typeof chart === "string") {
    queryVars.chart_id = chart;
  } else {
    queryVars.configuration = chart;
  }

  return fetch(fetchDataPath, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify(queryVars),
  }).then(handleResponseError);
};

export const saveDashboard = (dashboardConfig: DashboardConfig) => {
  return fetch(updateDashboardPath, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      [csrfParam]: csrfToken,
      configuration: dashboardConfig,
    }),
  }).then(handleResponseError);
};

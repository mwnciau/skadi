import type { ChartConfig, DashboardConfig, TabFilters } from "../../types";

const callingScript = document.querySelector<HTMLElement>("[data-dashboard-config]");
const fetchDataPath = callingScript?.dataset?.fetchDataPath as string;
const updateDashboardPath = callingScript?.dataset?.updateDashboardPath as string;

const csrfParam = (document.querySelector("meta[name=csrf-param]") as HTMLMetaElement)?.content;
const csrfToken = (document.querySelector("meta[name=csrf-token]") as HTMLMetaElement)?.content;

const handleResponseError = (response: Response) => {
  return response.text().then((text) => {
    const body = text ? JSON.parse(text) : null;

    if (!response.ok) {
      throw new Error(body?.error ?? `Request failed with status ${response.status}`);
    }

    return body;
  });
};

export const fetchChartData = (chartId: string, tabFilters: TabFilters, chartConfig: ChartConfig | null) => {
  const queryVars: Record<string, unknown> = {
    [csrfParam]: csrfToken,
  };

  if (tabFilters.date_from) {
    queryVars.date_from = tabFilters.date_from;
  }
  if (tabFilters.date_to) {
    queryVars.date_to = tabFilters.date_to;
  }
  if (chartConfig) {
    queryVars.configuration = chartConfig;
  } else {
    queryVars.chart_id = chartId;
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

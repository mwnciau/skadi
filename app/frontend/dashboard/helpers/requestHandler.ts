import { ChartConfig, DashboardConfig, DashboardTabConfig, TabFilters } from "../../types";

const baseUrl = window.location.toString().endsWith("/")
    ? window.location
    : window.location.toString() + "/";

const handleResponseError = (response: Response) => {
  return response.text().then((text) => {
    const body = text ? JSON.parse(text) : null;

    if (!response.ok) {
      throw new Error(body?.error ?? `Request failed with status ${response.status}`);
    }

    return body;
  });
}

export const fetchChartData = (chartId: string, tabFilters: TabFilters, chartConfig: ChartConfig | null) => {
  let queryVars = [];

  if (tabFilters.date_from) {
    queryVars.push(`date_from=${tabFilters.date_from}`)
  }
  if (tabFilters.date_to) {
    queryVars.push(`date_to=${tabFilters.date_to}`)
  }
  if (chartConfig) {
    queryVars.push(`configuration=${encodeURIComponent(JSON.stringify(chartConfig))}`);
  } else {
    queryVars.push(`chart_id=${chartId}`);
  }

  return fetch(`${baseUrl}data?${queryVars.join("&")}`)
    .then(handleResponseError);
}

export const saveDashboard = (dashboardConfig: DashboardConfig) => {
  let csrfParam = (document.querySelector("meta[name=csrf-param]") as HTMLMetaElement)?.content;
  let csrfToken = (document.querySelector("meta[name=csrf-token]") as HTMLMetaElement)?.content;

  return fetch(`${baseUrl}dashboard/update`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      [csrfParam]: csrfToken,
      configuration: dashboardConfig,
    }),
  })
    .then(handleResponseError);
};

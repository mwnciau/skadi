export type DateTime = string;

export type Filter = {
  verified: boolean;
  path: string;
  date_from: DateTime;
  date_to: DateTime;
}

export type Dataset = {
  id: string;
  label: string;
  type: "views" | "visits";
  filters: Filter;
}

export type ChartConfig = {
  id: string;
  type: "line";
  title: string;
  group: "day" | "week" | "month";
  datasets: Dataset[];
}

export type DashboardConfig = {
  id: string;
  title: string;
  children: ChartConfig[];
}

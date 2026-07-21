export type DateTime = string;

export type CommonDataset = {
  id: string;
  label: string;
  visible?: boolean;
  axis?: "right" | "left";
  type: "visits" | "views" | "events" | "percentage" | "sql";
}

export type VisitDataset = CommonDataset & {
  type: "visits";
  date_from?: DateTime;
  date_to?: DateTime;
}

export type ViewDataset = CommonDataset & {
  type: "views";
  split_by?: "controller" | "controller_action" | "path" | "verb" | "version";

  view_action?: string;
  view_controller?: string;
  view_path?: string;
  view_verb?: string;
  view_version?: string;

  date_from?: DateTime;
  date_to?: DateTime;
}

export type EventDataset = CommonDataset & {
  type: "events";
  split_by?: "name";

  event_name?: string;

  date_from?: DateTime;
  date_to?: DateTime;
}

export type PercentageDataset = CommonDataset & {
  type: "percentage";
  numerator: string;
  denominator: string;
}

export type SqlDataset = CommonDataset & {
  type: "sql";
  sql: string;
}

export type Dataset = VisitDataset | ViewDataset | EventDataset | PercentageDataset | SqlDataset;

export type ChartConfig = {
  id: string;
  type: "bar" | "line";
  title: string;
  time_series?: "daily" | "weekly" | "monthly";
  date_from?: DateTime;
  date_to?: DateTime;
  verified?: boolean;
  unique_visits?: boolean;
  visit_tracking?: "any" | "anonymity_set" | "cookie";
  datasets: Dataset[];
}

export type DashboardConfig = {
  id: string;
  title: string;
  date_from?: string;
  date_to?: string;
  children: ChartConfig[];
}

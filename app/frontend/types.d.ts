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
}

export type ViewDataset = CommonDataset & {
  type: "views";
  split_by?: "controller" | "controller_action" | "path" | "verb" | "version";

  view_action?: string;
  view_controller?: string;
  view_path?: string;
  view_verb?: string;
  view_version?: string;
}

export type EventDataset = CommonDataset & {
  type: "events";
  split_by?: "name";

  event_name?: string;
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
  type: "line";
  title: string;
  group: "day" | "week" | "month";
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
  children: ChartConfig[];
}

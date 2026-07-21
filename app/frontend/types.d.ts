import type { ChartType, DefaultDataPoint } from "chart.js";

declare module "chart.js" {
  interface Chart<TType extends ChartType = ChartType, TData = DefaultDataPoint<TType>, TLabel = unknown> {
    hoveredPosition?: number | null;
  }
}

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

export type DataPoint = {x: string, y: number}
export type ResponseData = Record<string, DataPoint[]>
export type ChartDataset = {
  dataset: string;
  split: string;
  label: string;
  data: DataPoint[];
  axis: "left" | "right";
}
export type ChartData = ChartDataset[]

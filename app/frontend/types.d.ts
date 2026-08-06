import type { ChartType, DefaultDataPoint } from "chart.js";

declare module "chart.js" {
  interface Chart<TType extends ChartType = ChartType, TData = DefaultDataPoint<TType>, TLabel = unknown> {
    hoveredPosition?: number | null;
  }
}

export type DateFilter = string;

export type CommonDataset = {
  id: string;
  label: string;
  visible?: boolean;
  axis?: "right" | "left";
  type: string;
};

export type SchemaDataset = CommonDataset & {
  type: string;
  split_by?: string[];
  [key: string]: string | boolean | number | DateFilter;
};

export type PercentageDataset = CommonDataset & {
  type: "percentage";
  numerator: string;
  denominator: string;
};

export type SqlDataset = CommonDataset & {
  type: "sql";
  sql: string;
};

export type Dataset = (SchemaDataset | PercentageDataset | SqlDataset) & Record<string, string | boolean | number>;

export type ChartConfig = {
  id: string;
  type: "bar" | "line";
  title: string;
  description?: string;
  time_series?: "daily" | "weekly" | "monthly";
  date_from?: DateFilter;
  date_to?: DateFilter;
  verified_visits?: boolean;
  unique_by?: "visit" | "visitor";
  visit_tracking?: "any" | "anonymity_set" | "cookie";
  datasets: Dataset[];
};

export type DashboardTabConfig = {
  id: string;
  title: string;
  description?: string;
  date_from?: string;
  date_to?: string;
  children: ChartConfig[];
};

export type TabFilters = {
  date_from?: string;
  date_to?: string;
};

// Note: any changes to this type need to be mirrored in the backend validator app/models/skadi/dashboard_validator.rb
export type DashboardConfig = DashboardTabConfig[];

export type DataPoint = { x: string | null; y: number | null };
export type RawResponseData = {
  id: string;
  date: string | null;
  split: string | null;
  count: number;
}[];
export type ResponseData = Record<string, DataPoint[]>;
export type ChartDataset = {
  dataset: string;
  split: string;
  label: string;
  data: DataPoint[];
  axis: "left" | "right";
};
export type ChartData = ChartDataset[];

export type FieldSchema = {
  label?: string;
  type?: "date" | "string" | "number" | "boolean" | "percentage" | "sql";
  filter?: boolean;
  split?: boolean;
  description?: string;
  // For select filters
  options?: (string | { label: string; value: string })[];
  // For boolean/switch filters
  leftLabel?: string;
  leftValue?: string;
  rightLabel?: string;
  rightValue?: string;
};

export type DatasetSchema = {
  fields: Record<string, FieldSchema>;
};

export type DatabaseSchema = Record<string, DatasetSchema>;

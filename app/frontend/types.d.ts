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

export type BinarySchemaDatasetFilter = {
  field: string;
  operator: "=" | "!=" | ">" | ">=" | "<=" | "<" | "like" | "not like";
  value: boolean | number | string | DateFilter;
};
export type UnarySchemaDatasetFilter = {
  field: string;
  operator: "empty" | "not empty";
};
export type SchemaDatasetFilter = BinarySchemaDatasetFilter | UnarySchemaDatasetFilter;

export type SchemaDataset = CommonDataset & {
  type: string;
  split_by?: string[];
  filters?: SchemaDatasetFilter[];
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

export type Dataset = SchemaDataset | PercentageDataset | SqlDataset;

export type ChartConfig = {
  id: string;
  type: "bar" | "line" | "table";
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

export type ChartMetadata = {
  resultCount?: number;
  resultOffset?: number;
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

export type ChartFilters = {
  page?: number;
};

// Note: any changes to this type need to be mirrored in the backend validator app/models/skadi/dashboard_validator.rb
export type DashboardConfig = DashboardTabConfig[];

export type ChartDataPoint = { x: string | null; y: number | null };
export type RawChartResponseData = {
  id: string;
  date: string | null;
  split: string | null;
  count: number;
}[];
export type RawResponse = {
  resultCount?: number;
  resultOffset?: number;
  data: RawChartResponseData | TableData;
};
export type ChartDataset = {
  dataset: string;
  split: string;
  label: string;
  data: ChartDataPoint[];
  axis: "left" | "right";
};
export type ChartData = ChartDataset[];

export type TableRow = Record<string, string | number | boolean | null>;
export type TableData = TableRow[];

export type FieldSchema = {
  label?: string;
  type?: "boolean" | "date" | "number" | "one_of" | "string";
  filter?: boolean;
  split?: boolean;
  description?: string;
  // For select filters
  options?: (string | { label: string; value: string })[];
  // For boolean/switch filters
  leftLabel?: string;
  leftValue?: unknown;
  rightLabel?: string;
  rightValue?: unknown;
};

export type DatasetSchema = {
  fields: Record<string, FieldSchema>;
};

export type DatabaseSchema = Record<string, DatasetSchema>;

export type DateTime = string;

type CommonDataset = {
  id: string;
  label: string;
  visible?: boolean;
  axis?: "right" | "left";
}

export type ViewDataset = CommonDataset & {
  type: "views";
  unique_visits?: boolean;
  split_by?: "controller" | "controller_action" | "path" | "verb";
  verified?: boolean;

  view_action?: string;
  view_controller?: string;
  view_path?: string;
  view_verb?: string;

  // Filter to only views that have visits, or specific types of visit
  visit_tracking?: "any" | "anonymity_set" | "cookie";
}

export type VisitDataset = CommonDataset & {
  type: "visits";
  verified?: boolean;

  visit_tracking?: "any" | "anonymity_set" | "cookie";
}

export type PercentageDataset = CommonDataset & {
  type: "percentage";
  numerator: string;
  denominator: string;
}

export type Dataset = ViewDataset | VisitDataset | PercentageDataset;

export type ChartConfig = {
  id: string;
  type: "line";
  title: string;
  group: "day" | "week" | "month";
  date_from?: DateTime;
  date_to?: DateTime;
  datasets: Dataset[];
}

export type DashboardConfig = {
  id: string;
  title: string;
  children: ChartConfig[];
}

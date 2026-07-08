export type DateTime = string;

type CommonFilter = {
  verified?: boolean;
}

type CommonDataset = {
  id: string;
  label: string;
  visible?: boolean;
  axis?: "right" | "left";
}

export type ViewFilter = CommonFilter & {
  action?: string;
  controller?: string;
  path?: string;
  verb?: string;
  visit?: boolean | VisitFilter;
}

export type ViewDataset = CommonDataset & {
  type: "views";
  filters: ViewFilter;
}

export type VisitFilter = {
  verified?: boolean;
  tracked?: true | "anonymity_set" | "cookie";
}

export type VisitDataset = CommonDataset & {
  type: "visits";
  filters: VisitFilter;
}

export type PercentageDataset = CommonDataset & {
  type: "percentage";
  numerator: string;
  denominator: string;
}

export type Filter = ViewFilter | VisitFilter;
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

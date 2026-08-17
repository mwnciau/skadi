import type {
  BinarySchemaDatasetFilter,
  Dataset,
  PercentageDataset,
  SchemaDataset,
  SchemaDatasetFilter,
  SqlDataset,
  UnarySchemaDatasetFilter,
} from "../../types";

export const isPercentageDataset = (dataset: Dataset): dataset is PercentageDataset => dataset.type === "percentage";
export const isSqlDataset = (dataset: Dataset): dataset is SqlDataset => dataset.type === "sql";
export const isSchemaDataset = (dataset: Dataset): dataset is SchemaDataset => !isPercentageDataset(dataset) && !isSqlDataset(dataset);

export const isFilterUnary = (filter: SchemaDatasetFilter): filter is UnarySchemaDatasetFilter =>
  filter.operator === "empty" || filter.operator === "not empty";
export const isFilterBinary = (filter: SchemaDatasetFilter): filter is BinarySchemaDatasetFilter => !isFilterUnary(filter);

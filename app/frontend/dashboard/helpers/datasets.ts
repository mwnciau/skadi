import type {
  BinarySchemaDatasetFilter,
  DatabaseSchema,
  Dataset,
  DatasetSchema,
  DynamicDataset,
  FieldSchema,
  PercentageDataset,
  SchemaDatasetFilter,
  SqlDataset,
  UnarySchemaDatasetFilter,
} from "../../types";
import { databaseSchema } from "./databaseSchema";
import { formatString } from "./formatting";

export const isPercentageDataset = (dataset: Dataset): dataset is PercentageDataset => dataset.type === "percentage";
export const isSqlDataset = (dataset: Dataset): dataset is SqlDataset => dataset.type === "sql";
export const isDynamicDataset = (dataset: Dataset): dataset is DynamicDataset => !isPercentageDataset(dataset) && !isSqlDataset(dataset);

export const isFilterUnary = (filter: SchemaDatasetFilter): filter is UnarySchemaDatasetFilter =>
  filter.operator === "empty" || filter.operator === "not empty";
export const isFilterBinary = (filter: SchemaDatasetFilter): filter is BinarySchemaDatasetFilter => !isFilterUnary(filter);

const DEFAULT_VALUES = {
  boolean: true,
  date: new Date().toISOString().substring(0, 10),
  number: 0,
  one_of: "",
  string: "",
};

export const defaultFilterValueForField = (fieldSchema: FieldSchema) => {
  if (fieldSchema.type === "one_of" && fieldSchema.options) {
    const firstOption = fieldSchema.options[0];

    return typeof firstOption === "string" ? firstOption : (firstOption?.value ?? "");
  }

  return DEFAULT_VALUES[fieldSchema.type ?? "string"];
};

export const parseDatasetField = (
  dataset: DynamicDataset,
  field: string,
): {
  datasetType: keyof DatabaseSchema;
  targetSchema: DatasetSchema | undefined;
  field: string;
  fieldSchema: FieldSchema | undefined;
  association?: "belongs_to";
} => {
  if (!field.includes(".")) {
    return {
      datasetType: dataset.type,
      targetSchema: databaseSchema[dataset.type],
      field,
      fieldSchema: databaseSchema[dataset.type]?.fields?.[field],
    };
  }

  const [belongsToTable, splitField] = field.split(".", 2) as [string, string];

  return {
    datasetType: belongsToTable,
    targetSchema: databaseSchema[belongsToTable],
    field: splitField,
    fieldSchema: databaseSchema[belongsToTable]?.fields?.[splitField],
    association: "belongs_to",
  };
};

export const isFilterValid = (datasetSchema: DatasetSchema, filter: SchemaDatasetFilter) => {
  // Check whether the field actually exists in the schema
  if (!datasetSchema?.fields?.[filter.field]?.filter) {
    return false;
  }

  const fieldSchema = datasetSchema.fields[filter.field];
  if (!fieldSchema) {
    return false;
  }

  // Check the operator is compatible
  if (!datasetFilterOperators(fieldSchema).includes(filter.operator)) {
    return false;
  }

  // Simple case when the operator doesn't require a value
  if (isFilterUnary(filter)) {
    // These don't have a value so it's a simple check
    return !("value" in filter);
  }

  const fieldType = fieldSchema.type ?? "string";

  switch (fieldType) {
    case "one_of":
      return fieldSchema.options?.some((option) => {
        if (typeof option === "string") {
          return option === filter.value;
        }

        return option.value === filter.value;
      });
    case "date":
      return typeof filter.value === "string" && filter.value.match(/^\d{4}-[01]\d-[0-3]\d$/);
    default:
      return typeof filter.value === fieldType;
  }
};

export const datasetLabel = (datasetType: string) => {
  return databaseSchema[datasetType]?.label ?? formatString(datasetType);
};

export const datasetFieldLabel = (field: string, datasetType: string | undefined) => {
  return databaseSchema[datasetType ?? ""]?.fields?.[field]?.label ?? formatString(field);
};

const DATASET_FILTER_OPERATORS = {
  boolean: ["=", "!=", "empty", "not empty"],
  date: ["=", "!=", ">", ">=", "<=", "<", "empty", "not empty"],
  number: ["=", "!=", ">", ">=", "<=", "<", "empty", "not empty"],
  one_of: ["=", "!=", "empty", "not empty"],
  string: ["=", "!=", "like", "not like", "empty", "not empty"],
};

export const datasetFilterOperators = (fieldConfig: FieldSchema | undefined) => {
  return DATASET_FILTER_OPERATORS[fieldConfig?.type ?? "string"];
};

export const countDatasetOwner = (datasetType: string, count: string) => {
  const datasetSchema = databaseSchema[datasetType];

  // If it's a count defined on the current dataset or is a foreign key, it's owned by the current dataset
  if (count === datasetType || datasetSchema?.counts?.[count] || datasetSchema?.belongs_to?.includes(count)) {
    return datasetType;
  }

  // It's a custom count on a joined dataset, so we return that dataset
  return datasetSchema?.belongs_to?.find((belongsToTable) => {
    const belongsToSchema = databaseSchema[belongsToTable];
    return !!belongsToSchema?.counts?.[count];
  });
};

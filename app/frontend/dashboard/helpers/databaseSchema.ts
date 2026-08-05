import { DatabaseSchema } from "../../types";

export const databaseSchema: DatabaseSchema = JSON.parse(
  document.querySelector<HTMLElement>("[data-dashboard-config]")!.dataset.datasetSchema!,
);

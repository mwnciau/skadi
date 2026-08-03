export const datasetSchema = JSON.parse(
  document.querySelector<HTMLElement>("[data-dashboard-config]")!.dataset.datasetSchema!,
);

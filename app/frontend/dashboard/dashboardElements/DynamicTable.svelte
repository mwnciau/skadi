<script lang="ts">
import type { ChartConfig, ChartFilters, ChartMetadata, TableData, TableRow } from "../../types";
import Pagination from "../components/Pagination.svelte";
import { databaseSchema } from "../helpers/databaseSchema";
import { datasetFieldLabel, isDynamicDataset, parseDatasetField } from "../helpers/datasets";
import { formatDate } from "../helpers/formatting";

// Mimics app/models/skadi/dashboard_query.rb:4
const ITEMS_PER_PAGE = 10;
const PAGES_PER_CHUNK = 10;

const { chartConfig, chartFilters, chartMetadata, data, loading } : {
  chartConfig: ChartConfig,
  chartFilters: ChartFilters,
  chartMetadata: ChartMetadata,
  data: TableData,
  loading: boolean,
} = $props();

let page = $state(1);
let previousPage = $state(1);

const dataPageOffset = $derived(typeof chartMetadata.resultOffset === "number" ? chartMetadata.resultOffset / ITEMS_PER_PAGE : null);

const isPageInBounds = (page: number): boolean => {
  return dataPageOffset !== null && page > dataPageOffset && page <= dataPageOffset + PAGES_PER_CHUNK
}

const isLoading = $derived(loading || !isPageInBounds(page));

// This component is only loaded if there is data, and if there is data, there will be a resultCount
let resultCount = $derived(chartMetadata.resultCount as number);

const highestPage = $derived(Math.ceil(resultCount / ITEMS_PER_PAGE));
const boundedPage = $derived(Math.max(1, Math.min(page, highestPage ?? 1)));

// Keep track of the last valid data page so we can keep displaying old data while things load
const dataOffset = $derived((((isLoading ? previousPage : boundedPage) - 1) % PAGES_PER_CHUNK) * ITEMS_PER_PAGE);

const dataset = $derived(chartConfig.datasets[0]);
const fields: {
  label: string;
  value: string;
  type: string;
}[] = $derived.by(() => {
  let fields: string[];
  if (dataset && isDynamicDataset(dataset)) {
    if (dataset.selects?.length) {
      fields = dataset.selects;
    } else if (databaseSchema[dataset.type]) {
      fields = Object.entries(databaseSchema[dataset.type]?.fields ?? {})
        // Only select the selectable fields
        .flatMap(([field, fieldConfig]) => fieldConfig.select ? [field] : []);
    }
  }

  // Fall back to using fields provided in the data
  fields ??= Object.keys(data[0] as TableRow)

  return fields.flatMap((rawField) => {
    if (!dataset) {
      return [];
    }

    const {datasetType, field, fieldSchema} = parseDatasetField(dataset, rawField)

    return [{label: datasetFieldLabel(field, datasetType), value: rawField, type: fieldSchema?.type ?? "string"}];
  });
})

const setPage = (newPage: number) => {
  if (!isPageInBounds(newPage)) {
    previousPage = page;

    // Set the new page, triggering a fetch. Make sure it's a multiple of items per page + 1, so going backwards doesn't constantly require a request.
    chartFilters.page = newPage - ((newPage - 1) % PAGES_PER_CHUNK);
  }

  page = newPage;
}
</script>

<div class="w-full overflow-x-auto {isLoading ? "opacity-25" : ""}">
  <table>
    <thead>
      <tr>
        {#each fields as field}
          <th>{field.label}</th>
        {/each}
      </tr>
    </thead>
    <tbody>
      {#each Array(ITEMS_PER_PAGE) as _, i}
        {@const row = data[dataOffset + i]}
        {#if row}
          <tr>
            {#each fields as field}
              <td>
                {#if field.type === "date"}
                  {formatDate(row[field.value] as string, "day")}
                {:else if field.type === "boolean"}
                  {row[field.value] ? "Yes" : "No"}
                {:else}
                  {row[field.value]}
                {/if}
              </td>
            {/each}
          </tr>
        {/if}
      {/each}
    </tbody>
  </table>
  <Pagination class="mt-4" page={boundedPage} perPage={ITEMS_PER_PAGE} totalItems={resultCount} {setPage} />
</div>

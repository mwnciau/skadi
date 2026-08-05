<script lang="ts">
import type { ChartConfig, ChartData } from "../../types";
import Pagination from "../components/Pagination.svelte";

const { chartConfig, data } : {
  chartConfig: ChartConfig,
  data: ChartData,
} = $props();

const dataCount = $derived.by(() => {
  return data[0]?.data?.length ?? 0;
});

let page = $state(1);
const ITEMS_PER_PAGE = 10;
</script>

<div class="w-full overflow-x-auto">
  <table>
    <thead>
      <tr>
        {#if chartConfig.time_series}
          <th>Date</th>
        {/if}
        {#each data as dataset}
          <th>{dataset.label}</th>
        {/each}
      </tr>
    </thead>
    <tbody>
      {#each Array(ITEMS_PER_PAGE) as _, i}
        {@const index = i + (page - 1) * ITEMS_PER_PAGE}
        {#if index < dataCount}
          <tr>
            {#if chartConfig.time_series}
              <td>{data[0]?.data[index]?.x}</td>
            {/if}
            {#each data as dataset}
              <td>{dataset.data[index]?.y}</td>
            {/each}
          </tr>
        {/if}
      {/each}
    </tbody>
  </table>
  <Pagination class="mt-4" page={page} perPage={ITEMS_PER_PAGE} totalItems={dataCount} setPage={(newPage: number) => page = newPage} />
</div>

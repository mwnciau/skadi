<script lang="ts">
import type {ChartConfig} from "../../types";

const { chartConfig }: {
  chartConfig: ChartConfig;
} = $props();
</script>

<input type="text" bind:value={chartConfig.title} />
<p>{JSON.stringify(chartConfig)}</p>
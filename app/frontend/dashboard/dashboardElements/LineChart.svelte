<script lang="ts">
import { onMount, untrack } from "svelte";
import { Chart } from "chart.js/auto";
import type { ChartConfig, Dataset } from "../../types.d.ts";
import ChartEditor from "../editors/ChartEditor.svelte";
import {processDerivedDatasets} from "../helpers/processData";

let { chartConfig, startEditing, onDelete }: {
  chartConfig: ChartConfig;
  startEditing: boolean;
  onDelete: () => void;
} = $props();

let canvas = $state<HTMLCanvasElement>();
let editing = $state(startEditing);
let confirmDelete: boolean = $state(false);

let chart: Chart<"line", {x: string, y: number}, unknown>;
let data : Record<string, {x: string, y: number}[]>;

onMount(() => {
  Chart.defaults.font.size = 18;
  chart = buildChart(canvas!);
  updateChartData();

  updateChartTitle();
  updateChartAxesDisplay();
  chart.update();

  return () => chart?.destroy();
});

$effect(() => {
  updateChartAxesDisplay();
  chart.update();
})
const updateChartAxesDisplay = () => {
  chart.options.scales.y1.display = chartConfig.datasets.some((dataset) => dataset.axis === "right");
}

$effect(() => {
  if (!chart) {
    return;
  }

  updateChartTitle();
  chart.update();
})

const updateChartTitle = () => {
  chart.options.plugins.title.text = chartConfig.title;
}

const fetchData = () => {
  const chartConfigJSON = encodeURIComponent(JSON.stringify(chartConfig));
  return fetch(`/skadi/data/${chartConfig.id}?config=${chartConfigJSON}`)
    .then((response) => {
      if (!response.ok) {
        return response.json().then((body) => {
          throw new Error(body.error ?? `Request failed with status ${response.status}`);
        });
      }

      return response.json();
    })
    .then((items) => {
      data = {};

      for (const item of items) {
        const key = item.split ? `${item.id} ${item.split}` : item.id;
        data[key] ??= [];
        data[key].push({x: item.label, y: item.count});
      }

      processDerivedDatasets(chartConfig.datasets, data);

      updateChartData();
      chart.update();
    });
}

const updateChartData = () => {
  if (!chart || !data) {
    return;
  }

  chart.data.datasets = chartConfig.datasets
    .filter((dataset: Dataset) => dataset.visible !== false)
    .flatMap((dataset: Dataset) => {
      let datasetIds = {}

      const splitDatasetIds = Object.keys(data)
        .filter((id) => id.startsWith(dataset.id))

      for (let splitDatasetId of splitDatasetIds) {
        const split = splitDatasetId.replace(/^[^ ]+ ?/, "");

        datasetIds[split] = splitDatasetId
      }

      return Object.entries(datasetIds).map(([split, datasetId]) => ({
        label: split ? `${dataset.label} ${split}`.trim() : dataset.label,
        data: data[datasetId],
        yAxisID: dataset.axis === "right" ? "y1" : "y",
        fill: false,
      }));
    });
}

const reloadChart = () => {
  return fetchData();
}

onMount(() => {
  fetchData();
})
</script>

<div class="relative w-full aspect-video">
  <canvas bind:this={canvas}></canvas>
</div>


{#if editing}
  <ChartEditor
    {chartConfig}
    reloadChart={reloadChart}
    onCancel={() => (editing = false)}
  />
{:else}
  <div class="flex gap-2">
    <button onclick={() => (editing = true)}>Edit</button>

    {#if confirmDelete}
      <button type="button" class="bg-dawn-100 ml-auto" onclick={onDelete}>Yes, delete this chart</button>
    {:else}
      <button type="button" class="bg-dawn-100 ml-auto" onclick={() => (confirmDelete = true)}>Delete</button>
    {/if}
</div>
{/if}

<script module lang="ts">
  const buildChart = (canvas: HTMLCanvasElement): Chart<"line", {x: string, y: number}, unknown> => {
    return new Chart(canvas, {
      type: "line",
      data: {
        datasets: [],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { position: "top" },
          title: { display: true, text: "Total visits" },
          tooltip: {
            // Show all datasets in the tooltip on the same x-coordinate
            intersect: false,
            mode: "x",
            // Show the tooltip on the nearest data point
            position: "nearest",
            // Show the tooltip below the point
            xAlign: "center",
            yAlign: "top",
            //
            caretPadding: 10,
            caretSize: 8,
          },
        },
        scales: {
          x: {
            ticks: {
              maxTicksLimit: 16,
              minRotation: 40,
              // The label sizes are all dates so Chart.js doesn't need to look at multiple to see the size
              sampleSize: 1,
            },
          },
          y: { beginAtZero: true },
          y1: { beginAtZero: true, position: "right", grid: { drawOnChartArea: false } },
        },
      },
      plugins: [{
        id: 'verticalLineOnHover',
        afterDraw: (chart) => {
          // Check if the tooltip is active and has data points
          if (chart.tooltip?._active?.length) {
            const activePoint = chart.tooltip._active[0];
            const ctx = chart.ctx;
            const x = activePoint.element.x;
            const topY = chart.scales.y.top;
            const bottomY = chart.scales.y.bottom;

            ctx.save();
            ctx.beginPath();
            ctx.moveTo(x, topY);
            ctx.lineTo(x, bottomY);

            ctx.lineWidth = 1;
            ctx.strokeStyle = 'rgb(0, 0, 0, 0.4)';

            ctx.setLineDash([4, 6]);

            ctx.stroke();
            ctx.restore();
          }
        }
      }],
    });
  }
</script>

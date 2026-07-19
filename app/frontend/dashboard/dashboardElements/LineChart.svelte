<script lang="ts">
import { onMount } from "svelte";
import { Chart } from "chart.js/auto";
import type { ChartConfig, Dataset } from "../../types.d.ts";

let { chartConfig, data } = $props<{
  chartConfig: ChartConfig;
  data: Record<string, {x: string, y: number}[]>;
}>();

let canvas = $state<HTMLCanvasElement>();
let chart: Chart<"line", {x: string, y: number}, unknown>;

onMount(() => {
  Chart.defaults.font.size = 18;
  chart = buildChart(canvas!);
  updateChartData();
  updateChartConfig();

  chart.update();

  return () => chart?.destroy();
});

const updateChartConfig = () => {
  chart.options.plugins.title.text = chartConfig.title;

  chart.options.scales.y1.display = chartConfig.datasets.some((dataset) => dataset.axis === "right");
}

$effect(() => {
  if (!chart) {
    return;
  }

  updateChartConfig();
  chart.update();
});

const updateChartData = () => {
  if (!chart || !data) {
    return;
  }

  let leftAxis = false;
  let rightAxis = false;

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

      if (dataset.axis === "right") {
        rightAxis = true;
      } else {
        leftAxis = true;
      }

      return Object.entries(datasetIds).map(([split, datasetId]) => ({
        label: split ? `${dataset.label} ${split}`.trim() : dataset.label,
        data: data[datasetId],
        yAxisID: dataset.axis === "right" ? "y1" : "y",
        fill: false,
      }));
    });

  chart.options.scales.y.display = leftAxis;
  chart.options.scales.y1.display = rightAxis;
}

$effect(() => {
  if (!chart) {
    return;
  }

  updateChartData();
  chart.update();
});
</script>

<div class="relative w-full aspect-video">
  <canvas bind:this={canvas}></canvas>
</div>

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
            mode: "index",
            // Show the tooltip on the nearest data point
            position: "nearest",
            // Make tooltip caret bigger
            caretPadding: 10,
            caretSize: 8,
          },
        },
        scales: {
          x: {
            ticks: {
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

<script lang="ts">
import { onMount, untrack } from "svelte";
import { Chart } from "chart.js/auto";
import type { ChartConfig, Dataset } from "../../types.d.ts";
import ChartEditor from "../editors/ChartEditor.svelte";

let { chartConfig }: { chartConfig: ChartConfig } = $props();

let canvas = $state<HTMLCanvasElement>();

let chart: Chart<"line", {x: string, y: number}, unknown>;
let data : Record<string, {x: string, y: number}[]>;

onMount(() => {
  Chart.defaults.font.size = 18;
  chart = buildChart(canvas!);
  updateChartData();

  chart.options.plugins.title.text = chartConfig.title;

  return () => chart?.destroy();
});

// Keep the chart data up to date when the datasets change
$effect(() => {
  fetchData(chartConfig.id);
  updateChartData();
})

$effect(() => {
  if (!chart) {
    return;
  }

  chart.options.plugins.title.text = chartConfig.title;
  chart.update();
})

const fetchData = (chartId: string) => {
  fetch(`/skadi/data/${chartId}`)
    .then((response) => response.json())
    .then((items) => {
      data = Object.fromEntries(
        chartConfig.datasets.map((dataset: Dataset) => [dataset.id, []])
      );

      for (const item of items) {
        data[item.id].push({x: item.label, y: item.count});
      }

      updateChartData();
    });
}

const updateChartData = () => {
  if (!chart || !data) {
    return;
  }

  chart.data.datasets = chartConfig.datasets.map((dataset: Dataset) => ({
    label: dataset.label,
    data: data[dataset.id],
    fill: false,
  }));

  chart.update();
}
</script>

<ChartEditor {chartConfig} />
<div class="relative w-full aspect-video">
  <canvas bind:this={canvas}></canvas>
</div>
<p>{chartConfig.title}</p>

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

<script lang="ts">
import { Chart } from "chart.js/auto";
import { onMount } from "svelte";
import type { ChartData, ChartDataset, ChartDataPoint } from "../../types.d.ts";

let { data } : {
  data: ChartData;
} = $props();

let canvas = $state<HTMLCanvasElement>() as HTMLCanvasElement;
let chart: Chart<"line", ChartDataPoint[], unknown>;

onMount(() => {
  Chart.defaults.font.size = 18;
  chart = buildChart(canvas);
  updateChartData();

  chart.update();

  return () => chart?.destroy();
});

const updateChartData = () => {
  if (!chart || !data) {
    return;
  }

  let leftAxis = false;
  let rightAxis = false;

  chart.data.datasets = data.map((chartDataset: ChartDataset) => {
    if (chartDataset.axis === "right") {
      rightAxis = true;
    } else {
      leftAxis = true;
    }

    return {
      label: chartDataset.label,
      data: chartDataset.data,
      yAxisID: chartDataset.axis === "right" ? "y1" : "y",
      fill: false,
    };
  });

  if (chart.options.scales?.y) {
    chart.options.scales.y.display = leftAxis;
  }
  if (chart.options.scales?.y1) {
    chart.options.scales.y1.display = rightAxis;
  }
}

$effect(() => {
  if (!chart) {
    return;
  }

  updateChartData();
  chart.update();
});
</script>

<div class="relative w-full aspect-video pr-4">
  <canvas bind:this={canvas}></canvas>
</div>

<script module lang="ts">
  const buildChart = (canvas: HTMLCanvasElement): Chart<"line", {x: string, y: number}[], unknown> => {
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
          const activeElements = chart.tooltip?.getActiveElements();
          if (activeElements?.length) {
            const activePoint = activeElements[0];
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

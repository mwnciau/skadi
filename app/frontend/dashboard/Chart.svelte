<script lang="ts">
  import { Chart } from "chart.js/auto";
  import type { ChartConfig } from "../types";

  let { chartConfig }: { chartConfig: ChartConfig } = $props();

  let canvas = $state<HTMLCanvasElement>();

  let chart = null;
  let data = Object.fromEntries(
    chartConfig.datasets.map((dataset) => [dataset.id, []])
  );

  fetch(`/skadi/data/${chartConfig.id}`)
    .then((response) => response.json())
    .then((items) => {
      for (const item of items) {
        data[item.id].push({x: item.label, y: item.count});
      }

      initChart();
    });

  const initChart = () => {
    if (!canvas) return;

    Chart.defaults.font.size = 18;
    chart = new Chart(canvas, {
      type: "line",
      data: {
        //labels,
        datasets: chartConfig.datasets.map((dataset) => {
          return {
            label: dataset.name,
            data: data[dataset.id],
            tension: 0.5,
          };
        }),
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

  $effect(() => {
    return () => chart?.destroy();
  });
</script>

<div class="relative w-full aspect-16/9">
  <canvas bind:this={canvas}></canvas>
</div>

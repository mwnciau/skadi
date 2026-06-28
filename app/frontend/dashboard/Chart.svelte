<script lang="ts">
  import { Chart } from "chart.js/auto";
  import type { ChartConfig } from "../types";

  let { chartConfig }: { chartConfig: ChartConfig } = $props();

  let canvas = $state<HTMLCanvasElement>();

  let chart = null;
  let labels = [];
  let data = Object.fromEntries(
    chartConfig.datasets.map((dataset) => [dataset.id, {}])
  );

  fetch(`/skadi/data/${chartConfig.id}`)
    .then((response) => response.json())
    .then((items) => {
      let labelsInData = new Set();
      for (const item of items) {
        labelsInData.add(item.label);

        data[item.id][item.label] = item.count;
      }

      labels = [...labelsInData];
      labels.sort();

      for (let dataset in chartConfig.datasets) {
        console.log(dataset)
        data[dataset.id] = labels.map((label) => {
          return data[dataset.id][label] ?? 0;
        })
      }

      initChart();
    });

  const initChart = () => {
    if (!canvas) return;

    chart = new Chart(canvas, {
      type: "line",
      data: {
        labels,
        datasets: [
          {
            label: "Visit count",
            data,
            borderColor: "#4f46e5",
            backgroundColor: "rgba(79, 70, 229, 0.1)",
            tension: 0.5,
            fill: true,
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { position: "top" },
          title: { display: true, text: "Total visits" },
        },
        scales: {
          y: { beginAtZero: true },
        },
      },
    });
  }

  $effect(() => {


    return () => chart?.destroy();
  });
</script>

<div class="relative h-80 w-full">
  <canvas bind:this={canvas}></canvas>
</div>

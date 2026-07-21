<script lang="ts">
import { onMount } from "svelte";
import { Chart } from "chart.js/auto";
import type { ChartConfig, Dataset } from "../../types.d.ts";

let { chartConfig, data } = $props<{
  chartConfig: ChartConfig;
  data: Record<string, {x: string, y: number}[]>;
}>();

let canvas = $state<HTMLCanvasElement>();
let chart: Chart<"bar", {x: string, y: number}, unknown>;

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
  chart.options.plugins.tooltip.mode = chartConfig.time_series ? "index" : "x";
  chart.options.plugins.tooltip.yAlign = chartConfig.time_series ? undefined : "bottom";
  chart.options.hover.mode = chartConfig.time_series ? "index" : "x";
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

      const isSplit = Object.keys(datasetIds).some((split) => split !== "");

      // Without a time grouping, every row for a split shares the same (constant) label as
      // its x value, so splitting into separate datasets would plot them all at that one
      // x position. Instead, collapse into a single dataset and use the split as the x value,
      // so each split gets its own bar along the x axis.
      if (!chartConfig.time_series && isSplit) {
        return [{
          label: dataset.label,
          data: Object.entries(datasetIds).map(([split, datasetId]) => ({
            x: `${dataset.label} ${split}`,
            y: data[datasetId][0].y,
          })),
          yAxisID: dataset.axis === "right" ? "y1" : "y",
          //backgroundColor: AXIS_COLORS[dataset.axis] ?? AXIS_COLORS["left"],
          fill: false,
          skipNull: true,
        }];
      }

      return Object.entries(datasetIds).map(([split, datasetId]) => ({
        label: split ? `${dataset.label} ${split}`.trim() : dataset.label,
        data: data[datasetId],
        yAxisID: dataset.axis === "right" ? "y1" : "y",
        //backgroundColor: AXIS_COLORS[dataset.axis] ?? AXIS_COLORS["left"],
        fill: false,
        skipNull: true,
      }));
    });

  chart.options.plugins.legend.display = leftAxis && rightAxis;
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
  const buildChart = (canvas: HTMLCanvasElement): Chart<"bar", {x: string, y: number}, unknown> => {
    return new Chart(canvas, {
      type: "bar",
      data: {
        datasets: [],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          title: { display: true, text: "Total visits" },
          tooltip: {
            position: "average",
            // Don't require hovering on top of the bars
            intersect: false,
            mode: "index",
            // Make tooltip caret bigger
            caretPadding: 10,
            caretSize: 8,
          },
        },
        scales: {
          y: { beginAtZero: true },
          y1: { beginAtZero: true, position: "right", grid: { drawOnChartArea: false } },
        },
        hover: {
          mode: "index",
          intersect: false,
        },
        onHover: (event, activeElements, chart) => {
          let hoveredPosition;
          if (activeElements.length) {
            hoveredPosition = (activeElements[0].element.x + activeElements[activeElements.length - 1].element.x) / 2
          }
          else {
            hoveredPosition = null
          }

          // Only do the re-render if the hovered element has meaningfully changed
          if (hoveredPosition !== chart.hoveredPosition) {
            chart.hoveredPosition = hoveredPosition;

            // Re-render without animations
            chart.update('none');
          }
        },
      },
      plugins: [{
        id: 'highlightXAxisBand',
        beforeDatasetsDraw(chart, args, options) {
          const { ctx, hoveredPosition, scales: { x, y } } = chart;

          if (!hoveredPosition) {
            return;
          }

          const pixelWidth = x.getPixelForTick(1) - x.getPixelForTick(0);
          let pixelLeft = hoveredPosition - (pixelWidth / 2);

          ctx.save();

          // Draw background highlight
          ctx.fillStyle = "#3366CC11";
          ctx.fillRect(pixelLeft, y.top, pixelWidth, y.height);

          ctx.restore();
        }
      }],
    });
  }
</script>

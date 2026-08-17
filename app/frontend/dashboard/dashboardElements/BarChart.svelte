<script lang="ts">
import { Chart } from "chart.js/auto";
import { onMount } from "svelte";
import type { ChartConfig, ChartData, ChartDataPoint, ChartDataset } from "../../types.d.ts";

let { chartConfig, data } : {
  chartConfig: ChartConfig;
  data: ChartData;
} = $props();

let canvas = $state<HTMLCanvasElement>() as HTMLCanvasElement;
let chart: Chart<"bar", ChartDataPoint[], unknown>;

onMount(() => {
  Chart.defaults.font.size = 18;
  chart = buildChart(canvas);
  updateChartData();
  updateChartConfig();

  chart.update();

  return () => chart?.destroy();
});

const updateChartConfig = () => {
  if (chart.options.plugins?.tooltip) {
    chart.options.plugins.tooltip.mode = chartConfig.time_series ? "index" : "x";
    chart.options.plugins.tooltip.yAlign = chartConfig.time_series ? undefined : "bottom";
  }
  if (chart.options.hover) {
    chart.options.hover.mode = chartConfig.time_series ? "index" : "x";
  }
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
      skipNull: !chartConfig.time_series,
    };
  });

  if (chart.options.plugins?.legend) {
    // Don't show the legend if there is no time series - the x-axis instead labels the bars
    chart.options.plugins.legend.display = !!chartConfig.time_series;
  }
  if (chart.options.scales?.y) {
    chart.options.scales.y.display = leftAxis;
  }
  if (chart.options.scales?.y1) {
    chart.options.scales.y1.display = rightAxis;
  }
  chart.hoveredPosition = null;
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
  const buildChart = (canvas: HTMLCanvasElement): Chart<"bar", {x: string, y: number}[], unknown> => {
    return new Chart(canvas, {
      type: "bar",
      data: {
        datasets: [],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            display: false,
          },
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
        onHover: (_event, activeElements, chart) => {
          let hoveredPosition : number | null;
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
        beforeDatasetsDraw(chart, _args, _options) {
          const { ctx, hoveredPosition, scales: { x, y } } = chart;

          if (!hoveredPosition) {
            return;
          }

          const pixelWidth = x.ticks.length > 0 ? x.chart.chartArea.width / x.ticks.length : 0;
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

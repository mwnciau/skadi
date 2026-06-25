<script lang="ts">
  import { Chart } from "chart.js/auto";

  let canvas = $state<HTMLCanvasElement>();

  const labels = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul"];
  const data = [65, 59, 80, 81, 56, 55, 70];

  $effect(() => {
    if (!canvas) return;

    const chart = new Chart(canvas, {
      type: "line",
      data: {
        labels,
        datasets: [
          {
            label: "Sales",
            data,
            borderColor: "#4f46e5",
            backgroundColor: "rgba(79, 70, 229, 0.1)",
            tension: 0.3,
            fill: true,
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { position: "top" },
          title: { display: true, text: "Monthly Sales" },
        },
        scales: {
          y: { beginAtZero: true },
        },
      },
    });

    return () => chart.destroy();
  });
</script>

<div class="relative h-80 w-full">
  <canvas bind:this={canvas}></canvas>
</div>

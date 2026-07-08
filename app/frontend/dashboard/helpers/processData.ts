import {Dataset} from "../../types";

export const processDerivedDatasets = (datasets: Dataset[], data: Record<string, {x: string, y: number}[]>) => {
  for (const dataset of datasets) {
    if (dataset.type === "percentage") {
      const numerator = data[dataset.numerator];
      const denominator = data[dataset.denominator];

      let n = 0;
      let d = 0;

      // Loop through the sorted numerator and denominator arrays and calculate a percentage
      // where the x values both exist.
      while (n < numerator.length && d < denominator.length) {
        // The labels match so populate the percentage for this label
        if (numerator[n].x === denominator[d].x) {
          // If the denominator is zero, skip it to avoid division by zero
          if (denominator[d].y > 0) {
            data[dataset.id].push({
              x: numerator[n].x,
              y: Math.round((numerator[n].y / denominator[d].y) * 1000) / 10,
            });
          }

          n++;
          d++;
        }
        // If the numerator is behind the denominator, incremenet just it to catch up
        else if (numerator[n].x < denominator[d].x) {
          n++;
        }
        // And vice versa. If they're not equal, and the numerator isn't smaller, the denominator must be behind.
        else {
          d++;
        }
      }
    }
  }
}
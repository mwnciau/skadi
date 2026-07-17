import { ChartConfig, Dataset } from "../../types";

const months = {"01": "January", "02": "February", "03": "March", "04": "April", "05": "May", "06": "June", "07": "July", "08": "August", "09": "September", "10": "October", "11": "November", "12": "December"};
const shortMonths = {"01": "Jan", "02": "Feb", "03": "Mar", "04": "Apr", "05": "May", "06": "Jun", "07": "Jul", "08": "Aug", "09": "Sep", "10": "Oct", "11": "Nov", "12": "Dec"};

export const processLabels = (chartConfig: ChartConfig, data: Record<string, {x: string, y: number}[]>) => {
  for (const dataset of chartConfig.datasets) {
    if (!["day", "week", "month"].includes(chartConfig.group)) {
      continue;
    }

    let dateFn: (dateParts: string[]) => string;
    if (chartConfig.group === "month") {
      dateFn = (dateParts: string[]) => {
        return `${months[dateParts[1]]} ${dateParts[0]}`
      }
    } else if (chartConfig.group === "week") {
      dateFn = (dateParts: string[]) => {
        return `w/c ${+dateParts[2]} ${shortMonths[dateParts[1]]} ${dateParts[0].substring(2, 2)}`
      }
    } else {
      dateFn = (dateParts: string[]) => {
        return `${+dateParts[2]} ${shortMonths[dateParts[1]]} ${dateParts[0].substring(2, 2)}`
      }
    }

    // Loop through the returned data to find rows for this dataset
    for (const datasetId of Object.keys(data)) {
      if (!datasetId.startsWith(dataset.id)) {
        continue;
      }

      for (const item of data[datasetId]) {
        const dateParts = item.x.split("-", 3);

        item.x = dateFn(dateParts);
      }
    }
  }
}

export const processDerivedDatasets = (datasets: Dataset[], data: Record<string, {x: string, y: number}[]>) => {
  for (const dataset of datasets) {
    if (dataset.type === "percentage") {
      const numerator = data[dataset.numerator];
      const denominator = data[dataset.denominator];

      let n = 0;
      let d = 0;

      if (!numerator || !denominator) {
        console.error(`Could not find numerator or denominator for percentage dataset ${dataset.id}`);
        delete data[dataset.id];

        continue;
      }

      data[dataset.id] = [];

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
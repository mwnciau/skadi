import { ChartConfig, Dataset } from "../../types";

const months: Record<string, string> = {"01": "January", "02": "February", "03": "March", "04": "April", "05": "May", "06": "June", "07": "July", "08": "August", "09": "September", "10": "October", "11": "November", "12": "December"};
const shortMonths: Record<string, string> = {"01": "Jan", "02": "Feb", "03": "Mar", "04": "Apr", "05": "May", "06": "Jun", "07": "Jul", "08": "Aug", "09": "Sep", "10": "Oct", "11": "Nov", "12": "Dec"};

export const processLabels = (chartConfig: ChartConfig, data: Record<string, {x: string, y: number}[]>) => {
  for (const dataset of chartConfig.datasets) {
    if (!chartConfig.time_series) {
      continue;
    }

    let dateFn: (dateParts: string[]) => string;
    if (chartConfig.time_series === "monthly") {
      dateFn = (dateParts: string[]) => {
        return `${months[dateParts[1]]} ${dateParts[0]}`
      }
    }
    else if (chartConfig.time_series === "weekly") {
      dateFn = (dateParts: string[]) => {
        return `w/c ${+dateParts[2]} ${shortMonths[dateParts[1]]} ${dateParts[0].substring(2, 2)}`
      }
    }
    // time_series = "daily"
    else {
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

export const processDerivedDatasets = (chart: ChartConfig, data: Record<string, {x: string, y: number}[]>) => {
  for (const dataset of chart.datasets) {
    if (dataset.type === "percentage") {
      const numerator = data[dataset.numerator];
      const denominator = data[dataset.denominator];

      if (!numerator || !denominator) {
        console.error(`Could not find numerator or denominator for percentage dataset ${dataset.id}`);
        delete data[dataset.id];

        continue;
      }

      if (chart.time_series) {
        data[dataset.id] = populatePercentageData(numerator, denominator);
      } else {
        // If there is no time-series, there is only one item per dataset
        data[dataset.id] = [{x: dataset.label, y: Math.round((numerator[0].y / denominator[0].y) * 1000) / 10}]
      }
    }
  }
}

const populatePercentageData = (numerator: {x: string, y: number}[], denominator: {x: string, y: number}[]) => {
  let n = 0;
  let d = 0;
  const percentageData = [];

  // Loop through the sorted numerator and denominator arrays and calculate a percentage
  // where the x values both exist.
  while (n < numerator.length && d < denominator.length) {
    // The labels match so populate the percentage for this label
    if (numerator[n].x === denominator[d].x) {
      // If the denominator is zero, skip it to avoid division by zero
      if (denominator[d].y > 0) {
        percentageData.push({
          x: numerator[n].x,
          y: Math.round((numerator[n].y / denominator[d].y) * 1000) / 10,
        });
      }

      n++;
      d++;
    }
    // If the numerator is behind the denominator, increment just it to catch up
    else if (numerator[n].x < denominator[d].x) {
      n++;
    }
    // And vice versa. If they're not equal, and the numerator isn't smaller, the denominator must be behind.
    else {
      d++;
    }
  }

  return percentageData;
}

export const fillDataGaps = (chart: ChartConfig, data: Record<string, {x: string, y: number | null}[]>) => {
  if (!chart.time_series) {
    // There will be no gaps if there is no time series
    return;
  }

  let uniqueXValues = new Set<string>();

  for (const dataPoints of Object.values(data)) {
    for (const dataPoint of dataPoints) {
      uniqueXValues.add(dataPoint.x);
    }
  }

  const xValues: string[] = Array.from(uniqueXValues).sort();
  interpolateXValues(chart, xValues);

  for (const dataset of Object.keys(data)) {
    for (let index = 0; index < xValues.length; index++) {
      if (!data[dataset][index] || data[dataset][index].x > xValues[index]) {
        data[dataset].splice(index, 0, {x: xValues[index], y: chart.type === "line" ? null : 0});
      }
    }
  }
}

const interpolateXValues = (chart: ChartConfig, xValues: string[]) => {
  if (!chart.time_series) {
    return;
  }

  for (let i = 0; i < xValues.length - 1; i++) {
    let current = xValues[i];
    let currentDate = new Date(current);

    if (chart.time_series === "daily") {
      currentDate.setUTCDate(currentDate.getUTCDate() + 1);
    }
    else if (chart.time_series === "weekly") {
      currentDate.setUTCDate(currentDate.getUTCDate() + 7);
    }
    else if (chart.time_series === "monthly") {
      currentDate.setUTCMonth(currentDate.getUTCMonth() + 1);
    }

    let next = currentDate.toISOString().split("T", 1)[0];

    if (next !== xValues[i + 1] && next < xValues[xValues.length - 1]) {
      xValues.splice(i + 1, 0, next);
    }
  }
}

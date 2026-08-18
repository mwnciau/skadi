import type { ChartConfig, ChartDataPoint, ChartDataset, Dataset, RawChartResponseData } from "../../types";
import { isPercentageDataset } from "./datasets";
import { formatDate } from "./formatting";

type ChartResponseData = Record<string, ChartDataPoint[]>;

export default (localChartConfig: ChartConfig, items: RawChartResponseData): ChartDataset[] => {
  const responseData: Record<string, ChartDataPoint[]> = {};

  for (const item of items) {
    const key: string = item.split ? `${item.id} ${item.split}` : item.id;
    responseData[key] ??= [];
    responseData[key].push({ x: item.date, y: item.count });
  }

  processDerivedDatasets(localChartConfig, responseData);
  fillDataGaps(localChartConfig, responseData);
  formatDates(localChartConfig, responseData);
  return createChartData(localChartConfig, responseData);
};

const createChartData = (chart: ChartConfig, responseData: ChartResponseData): ChartDataset[] => {
  return chart.datasets
    .filter((dataset: Dataset) => dataset.visible !== false)
    .flatMap((dataset: Dataset) => {
      const datasetIds: Record<string, string> = {};

      const splitDatasetIds = Object.keys(responseData).filter((id) => id.startsWith(dataset.id));

      for (const splitDatasetId of splitDatasetIds) {
        const split = splitDatasetId.replace(/^[^ ]+ ?/, "");

        datasetIds[split] = splitDatasetId;
      }

      return Object.entries(datasetIds).map(([split, datasetId]) => {
        let label = dataset.label;
        const splitParts = split ? split.split("|~|") : [];
        const numSplits = Math.max(splitParts.length, (dataset as { split_by?: string[] }).split_by?.length ?? 0);

        // Replace split-part placeholders in the label
        for (let i = 0; i < numSplits; i++) {
          const matcher = new RegExp(`%${i + 1}(?!\\d)(?:\\(([^)]+)\\))?`, "g");

          const match = label.match(matcher);
          if (match) {
            label = label.replace(matcher, (_match, defaultReplacement) => {
              return splitParts[i] ? splitParts[i] : (defaultReplacement ?? "n/a");
            });
          } else {
            const splitPart = splitParts[i] ? splitParts[i] : "n/a";

            label = `${label}, ${splitPart}`;
          }
        }

        if (!chart.time_series && responseData[datasetId]?.[0]) {
          responseData[datasetId][0].x = label;
        }

        return {
          dataset: datasetId,
          split: split,
          label: label,
          data: responseData[datasetId] as ChartDataPoint[],
          axis: dataset.axis === "right" ? "right" : "left",
        };
      });
    });
};

const processDerivedDatasets = (chart: ChartConfig, data: ChartResponseData) => {
  for (const dataset of chart.datasets) {
    if (isPercentageDataset(dataset)) {
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
        const denominatorY = denominator[0]?.y;
        const numeratorY = numerator[0]?.y;

        if (denominatorY && typeof numeratorY === "number") {
          // If the denominator is zero, skip it to avoid division by zero
          const yValue = numeratorY / denominatorY;

          // If there is no time-series, there is only one item per dataset
          data[dataset.id] = [{ x: dataset.label, y: Math.round(yValue * 1000) / 10 }];
        }
      }
    }
  }
};

const populatePercentageData = (numerator: ChartDataPoint[], denominator: ChartDataPoint[]) => {
  let n = 0;
  let d = 0;
  const percentageData = [];

  // Loop through the sorted numerator and denominator arrays and calculate a percentage
  // where the x values both exist.
  while (n < numerator.length && d < denominator.length) {
    const numeratorX = numerator[n]?.x as string;
    const denominatorX = denominator[d]?.x as string;

    // The labels match so populate the percentage for this label
    if (numeratorX === denominatorX) {
      const numeratorY = numerator[n]?.y ?? null;
      const denominatorY = denominator[d]?.y ?? null;

      if (numeratorY !== null && denominatorY !== null && denominatorY !== 0) {
        // If the denominator is zero, skip it to avoid division by zero
        percentageData.push({
          x: numerator[n]?.x ?? null,
          y: Math.round((numeratorY / denominatorY) * 1000) / 10,
        });
      }

      n++;
      d++;
    }
    // If the numerator is behind the denominator, increment just it to catch up
    else if (numeratorX < denominatorX) {
      n++;
    }
    // And vice versa. If they're not equal, and the numerator isn't smaller, the denominator must be behind.
    else {
      d++;
    }
  }

  return percentageData;
};

const fillDataGaps = (chart: ChartConfig, data: Record<string, ChartDataPoint[]>) => {
  if (!chart.time_series) {
    // There will be no gaps if there is no time series
    return;
  }

  const uniqueXValues = new Set<string>();

  for (const dataPoints of Object.values(data)) {
    for (const dataPoint of dataPoints) {
      uniqueXValues.add(dataPoint.x as string);
    }
  }

  const xValues: string[] = Array.from(uniqueXValues).sort();
  interpolateXValues(chart, xValues);

  for (const dataset of Object.values(data)) {
    // Ensure the data is sorted by date, moving nulls to the end so as to not break gap-filling
    dataset.sort((a, b) => (a.x ?? "\uffff").localeCompare(b.x ?? "\uffff"));

    for (let index = 0; index < xValues.length; index++) {
      const xValue = xValues[index] as string;
      const dataPoint = dataset[index];

      if (!dataPoint || (dataPoint.x ?? "") > xValue) {
        dataset.splice(index, 0, { x: xValue, y: null });
      }
    }
  }
};

const interpolateXValues = (chart: ChartConfig, xValues: string[]) => {
  if (!chart.time_series) {
    return;
  }

  for (let i = 0; i < xValues.length - 1; i++) {
    const current = xValues[i];
    const last = xValues[xValues.length - 1];

    if (!current || !last) {
      continue;
    }

    const currentDate = new Date(current);

    if (chart.time_series === "daily") {
      currentDate.setUTCDate(currentDate.getUTCDate() + 1);
    } else if (chart.time_series === "weekly") {
      currentDate.setUTCDate(currentDate.getUTCDate() + 7);
    } else if (chart.time_series === "monthly") {
      currentDate.setUTCMonth(currentDate.getUTCMonth() + 1);
    }

    const next = currentDate.toISOString().substring(0, 10);

    if (next !== xValues[i + 1] && next < last) {
      xValues.splice(i + 1, 0, next);
    }
  }
};

const timeSeriesToFormat = {
  monthly: "month",
  weekly: "week",
  daily: "day",
};
const formatDates = (chartConfig: ChartConfig, data: ChartResponseData) => {
  for (const dataset of chartConfig.datasets) {
    if (!chartConfig.time_series) {
      continue;
    }

    const dateFormat = timeSeriesToFormat[chartConfig.time_series] as "month" | "week" | "day";

    // Loop through the returned data to find rows for this dataset
    for (const [datasetId, dataPoints] of Object.entries(data)) {
      if (!datasetId.startsWith(dataset.id)) {
        continue;
      }

      for (const item of dataPoints) {
        if (!item.x) {
          continue;
        }

        item.x = formatDate(item.x, dateFormat);
      }
    }
  }
};

export const formatString = (string: string) => {
  return (
    string
      // Replace underscores with spaces
      .replace(/_/g, " ")
      // Capitalise the first letter
      .replace(/^[a-z]/, (letter) => letter.toLocaleUpperCase())
      // A few QoL replacements
      .replace(/\bSql\b/g, "SQL")
      .replace(/\bUtm\b/g, "UTM")
  );
};

const months: Record<string, string> = {
  "01": "January",
  "02": "February",
  "03": "March",
  "04": "April",
  "05": "May",
  "06": "June",
  "07": "July",
  "08": "August",
  "09": "September",
  "10": "October",
  "11": "November",
  "12": "December",
};
const shortMonths: Record<string, string> = {
  "01": "Jan",
  "02": "Feb",
  "03": "Mar",
  "04": "Apr",
  "05": "May",
  "06": "Jun",
  "07": "Jul",
  "08": "Aug",
  "09": "Sep",
  "10": "Oct",
  "11": "Nov",
  "12": "Dec",
};

export const formatDate = (date: unknown, format: "month" | "week" | "day"): string => {
  if (typeof date !== "string" || !date.match(/^\d{4}-\d{2}-\d{2}/)) {
    return `${date}`;
  }

  const [year, month, day] = date.substring(0, 10).split("-", 3);

  if (!year || !month || !day) {
    return date;
  }

  switch (format) {
    case "month":
      return `${months[month]} ${year}`;
    case "week":
      return `w/c ${+day} ${shortMonths[month]} ${year.substring(2, 4)}`;
    case "day":
      return `${+day} ${shortMonths[month]} ${year.substring(2, 4)}`;
  }
};

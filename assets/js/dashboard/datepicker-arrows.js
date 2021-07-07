import React from "react";
import {
  shiftDays,
  shiftMonths,
  formatISO,
  nowForSite,
  parseUTCDate,
  isBefore,
  isAfter,
} from "./date";
import { QueryButton } from "./query";

function renderArrow(query, site, period, prevDate, nextDate) {
  const insertionDate = parseUTCDate(site.insertedAt);
  const disabledLeft = isBefore(
    parseUTCDate(prevDate),
    insertionDate,
    period
  );
  const disabledRight = isAfter(
    parseUTCDate(nextDate),
    nowForSite(site),
    period
  );

  const leftClasses = `flex items-center px-2 border-r border-gray-300 rounded-l
      dark:border-gray-500 dark:text-gray-100 ${
      disabledLeft ? "bg-gray-300 dark:bg-gray-950" : "hover:bg-gray-200 dark:hover:bg-gray-900"
    }`;
  const rightClasses = `flex items-center px-2 rounded-r dark:text-gray-100 ${
      disabledRight ? "bg-gray-300 dark:bg-gray-950" : "hover:bg-gray-200 dark:hover:bg-gray-900"
    }`;
  return (
    <div className="flex rounded shadow bg-white mr-4 cursor-pointer dark:bg-gray-800">
      <QueryButton
        to={{ date: prevDate }}
        query={query}
        className={leftClasses}
        disabled={disabledLeft}
      >
        <svg
          className="feather h-4 w-4"
          xmlns="http://www.w3.org/2000/svg"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          strokeWidth="2"
          strokeLinecap="round"
          strokeLinejoin="round"
        >
          <polyline points="15 18 9 12 15 6"></polyline>
        </svg>
      </QueryButton>
      <QueryButton
        to={{ date: nextDate }}
        query={query}
        className={rightClasses}
        disabled={disabledRight}
      >
        <svg
          className="feather h-4 w-4"
          xmlns="http://www.w3.org/2000/svg"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          strokeWidth="2"
          strokeLinecap="round"
          strokeLinejoin="round"
        >
          <polyline points="9 18 15 12 9 6"></polyline>
        </svg>
      </QueryButton>
    </div>
  );
}

export default function DatePickerArrows({site, query}) {
  if (query.period === "month") {
    const prevDate = formatISO(shiftMonths(query.date, -1));
    const nextDate = formatISO(shiftMonths(query.date, 1));

    return renderArrow(query, site, "month", prevDate, nextDate);
  } if (query.period === "day") {
    const prevDate = formatISO(shiftDays(query.date, -1));
    const nextDate = formatISO(shiftDays(query.date, 1));

    return renderArrow(query, site, "day", prevDate, nextDate);
  }

  return null
}

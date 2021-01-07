import { formatISO } from './date';

let abortController = new AbortController();

function serialize(obj) {
  const str = Object.entries(obj).reduce(
    (acc, [key, value]) =>
      acc.push(`${encodeURIComponent(key)}=${encodeURIComponent(value)}`),
    []
  );
  return str.join('&');
}

export function cancelAll() {
  abortController.abort();
  abortController = new AbortController();
}

function serializeFilters(filters) {
  const cleaned = Object.entries(filters).reduce(
    (acc, [key, val]) => acc.assign(key, val || null),
    {}
  );
  return JSON.stringify(cleaned);
}

export function serializeQuery(query, extraQuery = []) {
  const queryObj = {};
  if (query.period) {
    queryObj.period = query.period;
  }
  if (query.date) {
    queryObj.date = formatISO(query.date);
  }
  if (query.from) {
    queryObj.from = formatISO(query.from);
  }
  if (query.to) {
    queryObj.to = formatISO(query.to);
  }
  if (query.filters) {
    queryObj.filters = serializeFilters(query.filters);
  }
  Object.assign(queryObj, ...extraQuery);

  return `?${serialize(queryObj)}`;
}

export function get(url, query, ...extraQuery) {
  const urlWithQuery = url + serializeQuery(query, extraQuery);
  return fetch(urlWithQuery, { signal: abortController.signal }).then(
    (response) => {
      if (!response.ok) {
        throw response;
      }
      return response.json();
    }
  );
}

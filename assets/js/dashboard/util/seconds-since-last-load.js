import { useState, useEffect } from "react";

// A function component that renders an integer value of how many
// seconds have passed from the last data load on the dashboard.
// Updates the value every second when the component is visible.
export function SecondsSinceLastLoad({ lastLoadTimestamp }) {
  const [timeNow, setTimeNow] = useState(new Date())

  useEffect(() => {
    const interval = setInterval(() => setTimeNow(new Date()), 1000)
    return () => clearInterval(interval)
  }, []);

  return Math.round(Math.abs(lastLoadTimestamp - timeNow) / 1000)
}

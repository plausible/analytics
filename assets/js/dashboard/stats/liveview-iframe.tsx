import React, { useEffect, useRef, useState } from "react";

type LiveViewIframeProps = {
    src: string;
    className?: string;
    minHeight?: number;   // fallback height
  };

  export function LiveViewIframe({ src, className, minHeight = 85 }: LiveViewIframeProps) {
    const ref = useRef<HTMLIFrameElement>(null);
    const [height, setHeight] = useState(minHeight);

    useEffect(() => {
      const onMessage = (ev: MessageEvent) => {
        if (ev.data?.type === "EMBEDDED_LV_SIZE") {
          setHeight(Math.max(minHeight, Number(ev.data.height) || minHeight));
        }
      };
      window.addEventListener("message", onMessage);
      return () => window.removeEventListener("message", onMessage);
    }, [minHeight]);

    return (
      <iframe
        ref={ref}
        src={src}
        style={{ width: "100%", border: "0", height }}
        className={className}
        title="LiveView Widget"
      />
    );
  }

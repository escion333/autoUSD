"use client";

import * as React from "react";
import clsx from "clsx";
import { Card } from "./Card";

export interface StatProps extends React.HTMLAttributes<HTMLDivElement> {
  label: string;
  value: string | number;
  delta?: {
    value: string | number;
    trend: "up" | "down" | "neutral";
  };
  sparkline?: number[];
  loading?: boolean;
}

export function Stat({ 
  className, 
  label,
  value,
  delta,
  sparkline,
  loading = false,
  ...props 
}: StatProps) {
  const maxSparklineValue = sparkline ? Math.max(...sparkline) : 0;
  const minSparklineValue = sparkline ? Math.min(...sparkline) : 0;
  const sparklineRange = maxSparklineValue - minSparklineValue || 1;
  
  return (
    <Card className={clsx("p-5", className)} {...props}>
      <div className="flex items-start justify-between">
        <div className="flex-1">
          <p className="text-sm font-medium text-text-muted mb-1">
            {label}
          </p>
          {loading ? (
            <div className="skeleton h-8 w-24 rounded-md mb-2" />
          ) : (
            <p className="text-3xl font-semibold text-text-title tabular-nums animate-value">
              {value}
            </p>
          )}
          {delta && !loading && (
            <div className={clsx(
              "inline-flex items-center gap-1 px-2 py-0.5 rounded-pill text-xs font-semibold mt-2",
              delta.trend === "up" && "bg-success-subtle text-success",
              delta.trend === "down" && "bg-error-subtle text-error",
              delta.trend === "neutral" && "bg-mist text-text-muted"
            )}>
              {delta.trend === "up" && (
                <svg className="h-3 w-3" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={3} d="M5 10l7-7m0 0l7 7m-7-7v18" />
                </svg>
              )}
              {delta.trend === "down" && (
                <svg className="h-3 w-3" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={3} d="M19 14l-7 7m0 0l-7-7m7 7V3" />
                </svg>
              )}
              <span>{delta.value}</span>
            </div>
          )}
        </div>
        {sparkline && !loading && (
          <div className="ml-4">
            <MiniSparkline data={sparkline} />
          </div>
        )}
      </div>
    </Card>
  );
}

interface MiniSparklineProps {
  data: number[];
  width?: number;
  height?: number;
  className?: string;
}

export function MiniSparkline({ 
  data, 
  width = 60, 
  height = 30,
  className 
}: MiniSparklineProps) {
  const max = Math.max(...data);
  const min = Math.min(...data);
  const range = max - min || 1;
  
  const points = data.map((value, index) => {
    const x = (index / (data.length - 1)) * width;
    const y = height - ((value - min) / range) * height;
    return `${x},${y}`;
  }).join(" ");
  
  const fillPoints = `0,${height} ${points} ${width},${height}`;
  
  return (
    <svg 
      width={width} 
      height={height} 
      className={clsx("overflow-visible", className)}
      aria-label="Sparkline chart"
    >
      <polyline
        points={fillPoints}
        fill="url(#sparkline-gradient)"
        opacity="0.15"
      />
      <polyline
        points={points}
        fill="none"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
        className="text-primary"
      />
      <defs>
        <linearGradient id="sparkline-gradient" x1="0%" y1="0%" x2="0%" y2="100%">
          <stop offset="0%" stopColor="#4CA8A1" />
          <stop offset="100%" stopColor="#4CA8A1" stopOpacity="0" />
        </linearGradient>
      </defs>
    </svg>
  );
}
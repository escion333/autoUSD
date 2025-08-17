"use client";

import * as React from "react";
import clsx from "clsx";

export interface SkeletonProps extends React.HTMLAttributes<HTMLDivElement> {
  variant?: "text" | "circular" | "rectangular";
  width?: string | number;
  height?: string | number;
  animation?: boolean;
}

export function Skeleton({ 
  className, 
  variant = "rectangular",
  width,
  height,
  animation = true,
  ...props 
}: SkeletonProps) {
  const variants = {
    text: "rounded-sm",
    circular: "rounded-full",
    rectangular: "rounded-md"
  };
  
  return (
    <div 
      className={clsx(
        animation ? "skeleton" : "bg-mist",
        variants[variant],
        className
      )}
      style={{
        width: width || "100%",
        height: height || (variant === "text" ? "1em" : "100%")
      }}
      {...props}
    />
  );
}
"use client";

import * as React from "react";
import clsx from "clsx";

type Variant = "neutral" | "positive" | "warning" | "error" | "primary" | "secondary";
type Size = "sm" | "md";

export interface BadgeProps extends React.HTMLAttributes<HTMLSpanElement> {
  variant?: Variant;
  size?: Size;
}

export function Badge({ 
  className, 
  variant = "neutral",
  size = "md",
  children,
  ...props 
}: BadgeProps) {
  const variants = {
    neutral: "bg-mist text-text-muted",
    positive: "bg-success-subtle text-success",
    warning: "bg-warning-subtle text-warning",
    error: "bg-error-subtle text-error",
    primary: "bg-primary-subtle text-primary",
    secondary: "bg-secondary/20 text-text-title"
  };

  const sizes = {
    sm: "px-2 py-0.5 text-xs",
    md: "px-2.5 py-0.5 text-xs"
  };
  
  return (
    <span 
      className={clsx(
        "inline-flex items-center rounded-pill font-semibold transition-colors",
        variants[variant],
        sizes[size],
        className
      )} 
      {...props}
    >
      {children}
    </span>
  );
}
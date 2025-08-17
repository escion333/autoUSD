"use client";

import * as React from "react";
import clsx from "clsx";

export interface CardProps extends React.HTMLAttributes<HTMLDivElement> {
  glass?: boolean;
  elevation?: "none" | "sm" | "md" | "lg";
}

export function Card({ 
  className, 
  glass = false,
  elevation = "sm",
  children,
  ...props 
}: CardProps) {
  const elevations = {
    none: "",
    sm: "shadow-sm",
    md: "shadow-md hover:shadow-lg transition-shadow",
    lg: "shadow-lg hover:shadow-xl transition-shadow"
  };
  
  return (
    <div 
      className={clsx(
        glass ? "glass" : "card",
        !glass && elevations[elevation],
        className
      )} 
      {...props}
    >
      {children}
    </div>
  );
}

export function CardHeader({ 
  className, 
  ...props 
}: React.HTMLAttributes<HTMLDivElement>) {
  return (
    <div 
      className={clsx("p-5 pb-3 flex items-center justify-between", className)} 
      {...props}
    />
  );
}

export function CardTitle({ 
  className, 
  ...props 
}: React.HTMLAttributes<HTMLHeadingElement>) {
  return (
    <h3 
      className={clsx("text-lg font-heading font-semibold text-text-title", className)} 
      {...props}
    />
  );
}

export function CardDescription({ 
  className, 
  ...props 
}: React.HTMLAttributes<HTMLParagraphElement>) {
  return (
    <p 
      className={clsx("text-sm text-text-muted mt-1", className)} 
      {...props}
    />
  );
}

export function CardContent({ 
  className, 
  ...props 
}: React.HTMLAttributes<HTMLDivElement>) {
  return (
    <div 
      className={clsx("p-5", className)} 
      {...props}
    />
  );
}

export function CardFooter({ 
  className, 
  ...props 
}: React.HTMLAttributes<HTMLDivElement>) {
  return (
    <div 
      className={clsx(
        "p-5 pt-3 border-t border-border-subtle flex items-center", 
        className
      )} 
      {...props}
    />
  );
}
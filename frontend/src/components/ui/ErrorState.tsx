"use client";

import * as React from "react";
import clsx from "clsx";
import { Button } from "./Button";

export interface ErrorStateProps extends React.HTMLAttributes<HTMLDivElement> {
  title?: string;
  description?: string;
  error?: Error | string;
  action?: {
    label: string;
    onClick: () => void;
  };
}

export function ErrorState({ 
  className, 
  title = "Something went wrong",
  description,
  error,
  action,
  ...props 
}: ErrorStateProps) {
  const errorMessage = error instanceof Error ? error.message : error;
  
  return (
    <div 
      className={clsx(
        "flex flex-col items-center justify-center p-8 text-center",
        className
      )} 
      {...props}
    >
      <div className="mb-4 text-error">
        <svg className="h-12 w-12" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} 
            d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" 
          />
        </svg>
      </div>
      <h3 className="text-lg font-heading font-semibold text-text-title mb-2">
        {title}
      </h3>
      <p className="text-sm text-text-muted mb-2 max-w-sm">
        {description || "An unexpected error occurred. Please try again."}
      </p>
      {errorMessage && (
        <div className="mt-2 p-3 bg-error-subtle rounded-md max-w-md">
          <p className="text-xs font-mono text-error break-all">
            {errorMessage}
          </p>
        </div>
      )}
      {action && (
        <div className="mt-6">
          <Button 
            onClick={action.onClick}
            variant="primary"
            size="md"
          >
            {action.label}
          </Button>
        </div>
      )}
    </div>
  );
}
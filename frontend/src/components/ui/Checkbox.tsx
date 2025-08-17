"use client";

import * as React from "react";
import clsx from "clsx";

export interface CheckboxProps extends React.InputHTMLAttributes<HTMLInputElement> {
  label?: string;
  error?: boolean;
  errorMessage?: string;
}

export const Checkbox = React.forwardRef<HTMLInputElement, CheckboxProps>(
  ({ 
    className, 
    label,
    error = false,
    errorMessage,
    id,
    ...props 
  }, ref) => {
    const checkboxId = id || React.useId();
    
    return (
      <div className="flex flex-col">
        <div className="flex items-center">
          <input
            id={checkboxId}
            type="checkbox"
            className={clsx(
              "h-4 w-4 rounded border bg-white",
              "text-primary focus:ring-2 focus:ring-primary focus:ring-offset-2",
              "transition-colors cursor-pointer",
              "disabled:cursor-not-allowed disabled:opacity-50",
              error ? "border-error" : "border-border",
              className
            )}
            ref={ref}
            aria-invalid={error}
            aria-describedby={errorMessage ? `${checkboxId}-error` : undefined}
            {...props}
          />
          {label && (
            <label 
              htmlFor={checkboxId}
              className="ml-2 text-sm text-text-body cursor-pointer select-none"
            >
              {label}
            </label>
          )}
        </div>
        {errorMessage && (
          <p id={`${checkboxId}-error`} className="mt-1 text-sm text-error">
            {errorMessage}
          </p>
        )}
      </div>
    );
  }
);

Checkbox.displayName = "Checkbox";
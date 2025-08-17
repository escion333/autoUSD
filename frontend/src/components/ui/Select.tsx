"use client";

import * as React from "react";
import clsx from "clsx";

export interface SelectProps extends React.SelectHTMLAttributes<HTMLSelectElement> {
  error?: boolean;
  errorMessage?: string;
  label?: string;
  helperText?: string;
  placeholder?: string;
  options: Array<{ value: string; label: string; disabled?: boolean }>;
}

export const Select = React.forwardRef<HTMLSelectElement, SelectProps>(
  ({ 
    className, 
    error = false,
    errorMessage,
    label,
    helperText,
    options,
    id,
    placeholder = "Select an option",
    ...props 
  }, ref) => {
    const selectId = id || React.useId();
    
    return (
      <div className="w-full">
        {label && (
          <label 
            htmlFor={selectId}
            className="block text-sm font-medium text-text-title mb-1.5"
          >
            {label}
          </label>
        )}
        <div className="relative">
          <select
            id={selectId}
            className={clsx(
              "flex h-11 w-full rounded-md border bg-white px-3 py-2 text-sm",
              "appearance-none cursor-pointer",
              "placeholder:text-text-muted transition-colors",
              "focus-visible:outline-none focus-visible:focus-ring",
              "disabled:cursor-not-allowed disabled:opacity-50",
              error 
                ? "border-error text-error" 
                : "border-border hover:border-primary/50",
              className
            )}
            ref={ref}
            aria-invalid={error}
            aria-describedby={errorMessage ? `${selectId}-error` : undefined}
            {...props}
          >
            <option value="" disabled>
              {placeholder}
            </option>
            {options.map((option) => (
              <option 
                key={option.value} 
                value={option.value}
                disabled={option.disabled}
              >
                {option.label}
              </option>
            ))}
          </select>
          <div className="pointer-events-none absolute right-3 top-1/2 -translate-y-1/2">
            <svg className="h-4 w-4 text-text-muted" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
            </svg>
          </div>
        </div>
        {errorMessage && (
          <p id={`${selectId}-error`} className="mt-1.5 text-sm text-error flex items-center gap-1">
            <svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} 
                d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" 
              />
            </svg>
            {errorMessage}
          </p>
        )}
        {helperText && !errorMessage && (
          <p className="mt-1.5 text-sm text-text-muted">
            {helperText}
          </p>
        )}
      </div>
    );
  }
);

Select.displayName = "Select";
"use client";

import * as React from "react";
import clsx from "clsx";

export interface InputProps extends React.InputHTMLAttributes<HTMLInputElement> {
  error?: boolean;
  errorMessage?: string;
  label?: string;
  helperText?: string;
  icon?: React.ReactNode;
}

export const Input = React.forwardRef<HTMLInputElement, InputProps>(
  ({ 
    className, 
    type = "text",
    error = false,
    errorMessage,
    label,
    helperText,
    icon,
    id,
    ...props 
  }, ref) => {
    const inputId = id || React.useId();
    
    return (
      <div className="w-full">
        {label && (
          <label 
            htmlFor={inputId}
            className="block text-sm font-medium text-text-title mb-1.5"
          >
            {label}
          </label>
        )}
        <div className="relative">
          {icon && (
            <div className="absolute left-3 top-1/2 -translate-y-1/2 text-text-muted">
              {icon}
            </div>
          )}
          <input
            id={inputId}
            type={type}
            className={clsx(
              "flex h-11 w-full rounded-md border bg-white px-3 py-2 text-sm",
              "file:border-0 file:bg-transparent file:text-sm file:font-medium",
              "placeholder:text-text-muted transition-colors",
              "focus-visible:outline-none focus-visible:focus-ring",
              "disabled:cursor-not-allowed disabled:opacity-50",
              icon && "pl-10",
              error 
                ? "border-error text-error" 
                : "border-border hover:border-primary/50",
              className
            )}
            ref={ref}
            aria-invalid={error}
            aria-describedby={errorMessage ? `${inputId}-error` : undefined}
            {...props}
          />
        </div>
        {errorMessage && (
          <p id={`${inputId}-error`} className="mt-1.5 text-sm text-error flex items-center gap-1">
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

Input.displayName = "Input";
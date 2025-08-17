"use client";

import * as React from "react";
import clsx from "clsx";

export interface ToggleProps extends Omit<React.InputHTMLAttributes<HTMLInputElement>, 'type'> {
  label?: string;
  error?: boolean;
  errorMessage?: string;
}

export const Toggle = React.forwardRef<HTMLInputElement, ToggleProps>(
  ({ 
    className, 
    label,
    error = false,
    errorMessage,
    id,
    disabled = false,
    ...props 
  }, ref) => {
    const toggleId = id || React.useId();
    
    return (
      <div className="flex flex-col">
        <div className="flex items-center">
          <label className="relative inline-flex items-center cursor-pointer">
            <input
              id={toggleId}
              type="checkbox"
              className="sr-only peer"
              ref={ref}
              disabled={disabled}
              aria-invalid={error}
              aria-describedby={errorMessage ? `${toggleId}-error` : undefined}
              {...props}
            />
            <div className={clsx(
              "w-11 h-6 rounded-full transition-colors",
              "after:content-[''] after:absolute after:top-[2px] after:left-[2px]",
              "after:bg-white after:rounded-full after:h-5 after:w-5",
              "after:transition-transform peer-checked:after:translate-x-full",
              "peer-focus-visible:ring-2 peer-focus-visible:ring-primary peer-focus-visible:ring-offset-2",
              error 
                ? "bg-error/30 peer-checked:bg-error" 
                : "bg-border peer-checked:bg-primary",
              disabled && "opacity-50 cursor-not-allowed",
              className
            )}></div>
          </label>
          {label && (
            <span className={clsx(
              "ml-3 text-sm text-text-body select-none",
              disabled ? "opacity-50" : "cursor-pointer"
            )}>
              {label}
            </span>
          )}
        </div>
        {errorMessage && (
          <p id={`${toggleId}-error`} className="mt-1 text-sm text-error">
            {errorMessage}
          </p>
        )}
      </div>
    );
  }
);

Toggle.displayName = "Toggle";
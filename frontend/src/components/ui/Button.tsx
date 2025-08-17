"use client";

import * as React from "react";
import clsx from "clsx";

type Variant = "primary" | "secondary" | "subtle" | "ghost" | "link";
type Size = "sm" | "md" | "lg";

export interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: Variant;
  size?: Size;
  pill?: boolean;
  loading?: boolean;
  children: React.ReactNode;
}

export const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(
  ({ 
    className, 
    variant = "primary", 
    size = "md", 
    pill = false, 
    loading = false,
    disabled = false,
    children,
    ...props 
  }, ref) => {
    const base = "inline-flex items-center justify-center font-medium transition-all duration-fast focus-visible:outline-none focus-visible:focus-ring disabled:opacity-50 disabled:pointer-events-none";
    
    const sizes = {
      sm: "h-9 px-3 text-sm gap-1.5",
      md: "h-11 px-4 text-[15px] gap-2",
      lg: "h-12 px-5 text-base gap-2"
    };

    const radius = pill ? "rounded-pill" : size === "sm" ? "rounded-sm" : "rounded-md";
    
    const variants: Record<Variant, string> = {
      primary: "text-white bg-primary hover:bg-primary-hover shadow-md hover:shadow-lg active:scale-[0.98]",
      secondary: "text-text-title bg-secondary hover:bg-secondary-hover shadow-sm hover:shadow-md",
      subtle: "text-text-title bg-primary-subtle hover:bg-primary-subtle/80 hover:shadow-sm",
      ghost: "text-text-title hover:bg-mist",
      link: "text-primary hover:text-primary-hover underline-offset-2 hover:underline p-0 h-auto"
    };

    return (
      <button 
        ref={ref}
        className={clsx(
          base, 
          variant !== "link" && sizes[size], 
          variant !== "link" && radius, 
          variants[variant], 
          className
        )}
        disabled={disabled || loading}
        {...props}
      >
        {loading && (
          <svg 
            className="animate-spin -ml-1 h-4 w-4"
            xmlns="http://www.w3.org/2000/svg" 
            fill="none" 
            viewBox="0 0 24 24"
          >
            <circle 
              className="opacity-25" 
              cx="12" 
              cy="12" 
              r="10" 
              stroke="currentColor" 
              strokeWidth="4"
            />
            <path 
              className="opacity-75" 
              fill="currentColor" 
              d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
            />
          </svg>
        )}
        {children}
      </button>
    );
  }
);

Button.displayName = "Button";
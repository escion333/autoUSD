"use client";

import * as React from "react";
import clsx from "clsx";
import { Button } from "./Button";

export interface EmptyStateProps extends React.HTMLAttributes<HTMLDivElement> {
  icon?: React.ReactNode;
  title: string;
  description?: string;
  action?: {
    label: string;
    onClick: () => void;
  };
  secondaryAction?: {
    label: string;
    onClick: () => void;
  };
}

export function EmptyState({ 
  className, 
  icon,
  title,
  description,
  action,
  secondaryAction,
  ...props 
}: EmptyStateProps) {
  return (
    <div 
      className={clsx(
        "flex flex-col items-center justify-center p-8 text-center",
        className
      )} 
      {...props}
    >
      {icon && (
        <div className="mb-4 text-text-muted">
          {icon}
        </div>
      )}
      <h3 className="text-lg font-heading font-semibold text-text-title mb-2">
        {title}
      </h3>
      {description && (
        <p className="text-sm text-text-muted mb-6 max-w-sm">
          {description}
        </p>
      )}
      {(action || secondaryAction) && (
        <div className="flex gap-3">
          {action && (
            <Button 
              onClick={action.onClick}
              variant="primary"
              size="md"
            >
              {action.label}
            </Button>
          )}
          {secondaryAction && (
            <Button 
              onClick={secondaryAction.onClick}
              variant="subtle"
              size="md"
            >
              {secondaryAction.label}
            </Button>
          )}
        </div>
      )}
    </div>
  );
}
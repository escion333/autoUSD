'use client';

import { useState, useEffect } from 'react';
import { formatErrorDisplay, isRetryableError, ErrorSeverity } from '@/lib/utils/errors';

interface ErrorAlertProps {
  error: unknown;
  onRetry?: () => void;
  onDismiss?: () => void;
  autoHide?: boolean;
  autoHideDelay?: number;
}

export function ErrorAlert({ 
  error, 
  onRetry, 
  onDismiss,
  autoHide = false,
  autoHideDelay = 5000 
}: ErrorAlertProps) {
  const [isVisible, setIsVisible] = useState(true);
  const { message, severity, icon } = formatErrorDisplay(error);
  const canRetry = isRetryableError(error) && onRetry;

  useEffect(() => {
    if (autoHide) {
      const timer = setTimeout(() => {
        setIsVisible(false);
        onDismiss?.();
      }, autoHideDelay);
      return () => clearTimeout(timer);
    }
  }, [autoHide, autoHideDelay, onDismiss]);

  if (!isVisible) return null;

  const severityClasses: Record<ErrorSeverity, string> = {
    info: 'bg-primary-subtle border-primary/20 text-primary',
    warning: 'bg-warning-subtle border-warning/20 text-warning',
    error: 'bg-error-subtle border-error/20 text-error',
    critical: 'bg-error-subtle border-error text-error',
  };

  const buttonClasses: Record<ErrorSeverity, string> = {
    info: 'text-primary hover:text-primary-hover hover:bg-primary/10',
    warning: 'text-warning hover:text-warning/90 hover:bg-warning/10',
    error: 'text-error hover:text-error/90 hover:bg-error/10',
    critical: 'text-error hover:text-error/90 hover:bg-error/10',
  };

  return (
    <div className={`rounded-lg border p-4 ${severityClasses[severity]}`}>
      <div className="flex items-start">
        <span className="text-xl mr-3" aria-hidden="true">{icon}</span>
        <div className="flex-1">
          <p className="text-sm font-medium">{message}</p>
          {(canRetry || onDismiss) && (
            <div className="mt-3 flex gap-3">
              {canRetry && (
                <button
                  onClick={onRetry}
                  className={`text-sm font-medium px-3 py-1 rounded-md transition-colors ${buttonClasses[severity]}`}
                >
                  Try Again
                </button>
              )}
              {onDismiss && (
                <button
                  onClick={() => {
                    setIsVisible(false);
                    onDismiss();
                  }}
                  className="text-sm text-text-muted hover:text-text-body transition-colors"
                >
                  Dismiss
                </button>
              )}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

interface InlineErrorProps {
  error: unknown;
  className?: string;
}

export function InlineError({ error, className = '' }: InlineErrorProps) {
  const { message, icon } = formatErrorDisplay(error);
  
  return (
    <div className={`flex items-center gap-2 text-sm text-error ${className}`}>
      <span>{icon}</span>
      <span>{message}</span>
    </div>
  );
}

interface ToastErrorProps {
  error: unknown;
  duration?: number;
}

export function showErrorToast({ error, duration = 4000 }: ToastErrorProps) {
  const { message, icon, severity } = formatErrorDisplay(error);
  
  // Import toast from react-hot-toast when needed
  if (typeof window !== 'undefined') {
    import('react-hot-toast').then(({ toast }) => {
      switch (severity) {
        case 'info':
          toast(message, { icon, duration });
          break;
        case 'warning':
          toast(message, { icon, duration });
          break;
        case 'error':
        case 'critical':
          toast.error(message, { duration });
          break;
      }
    }).catch(() => {
      console.error(`${icon} ${message}`);
    });
  } else {
    console.error(`${icon} ${message}`);
  }
}
"use client";

import * as React from "react";
import clsx from "clsx";

export interface NavbarProps extends React.HTMLAttributes<HTMLElement> {
  logo?: React.ReactNode;
  transparent?: boolean;
}

export function Navbar({ 
  className, 
  logo,
  transparent = false,
  children,
  ...props 
}: NavbarProps) {
  return (
    <nav 
      className={clsx(
        "fixed top-0 left-0 right-0 z-40 h-16",
        transparent 
          ? "bg-white/80 backdrop-blur-md border-b border-border/50" 
          : "bg-surface border-b border-border",
        className
      )} 
      {...props}
    >
      <div className="container mx-auto px-4 h-full flex items-center justify-between">
        {logo && (
          <div className="flex items-center">
            {logo}
          </div>
        )}
        <div className="flex items-center gap-6">
          {children}
        </div>
      </div>
    </nav>
  );
}

export function NavbarBrand({ 
  className, 
  ...props 
}: React.HTMLAttributes<HTMLDivElement>) {
  return (
    <div 
      className={clsx("text-xl font-heading font-bold text-text-title", className)} 
      {...props}
    />
  );
}

export function NavbarNav({ 
  className, 
  ...props 
}: React.HTMLAttributes<HTMLUListElement>) {
  return (
    <ul 
      className={clsx("flex items-center gap-6", className)} 
      {...props}
    />
  );
}

export function NavbarItem({ 
  className,
  active = false,
  ...props 
}: React.HTMLAttributes<HTMLLIElement> & { active?: boolean }) {
  return (
    <li 
      className={clsx(
        "text-sm font-medium transition-colors cursor-pointer",
        active ? "text-primary" : "text-text-body hover:text-primary",
        className
      )} 
      {...props}
    />
  );
}
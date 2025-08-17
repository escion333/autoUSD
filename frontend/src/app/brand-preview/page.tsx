"use client";

import React, { useState } from "react";
import { Button } from "@/components/ui/Button";
import { Card, CardHeader, CardTitle, CardDescription, CardContent, CardFooter } from "@/components/ui/Card";
import { Input } from "@/components/ui/Input";
import { Select } from "@/components/ui/Select";
import { Checkbox } from "@/components/ui/Checkbox";
import { Toggle } from "@/components/ui/Toggle";
import { Badge } from "@/components/ui/Badge";
import { Stat } from "@/components/ui/Stat";
import { Navbar, NavbarBrand, NavbarNav, NavbarItem } from "@/components/ui/Navbar";
import { EmptyState } from "@/components/ui/EmptyState";
import { ErrorState } from "@/components/ui/ErrorState";
import { Skeleton } from "@/components/ui/Skeleton";
import Image from "next/image";

export default function BrandPreviewPage() {
  const [formValues, setFormValues] = useState({
    email: "",
    network: "",
    terms: false,
    notifications: true,
  });

  const sparklineData = [12, 19, 15, 25, 22, 30, 28, 35, 32, 40, 38, 45];
  
  return (
    <div className="min-h-screen bg-background">
      {/* Navbar */}
      <Navbar logo={<Image src="/LOGO.png" alt="autoUSD" width={120} height={36} />}>
        <NavbarNav>
          <NavbarItem active>Dashboard</NavbarItem>
          <NavbarItem>Positions</NavbarItem>
          <NavbarItem>Analytics</NavbarItem>
        </NavbarNav>
        <Button variant="primary" size="sm">
          Connect Wallet
        </Button>
      </Navbar>

      {/* Hero Section */}
      <section className="pt-24 pb-16 px-4">
        <div className="container mx-auto max-w-6xl">
          <div className="text-center mb-12">
            <h1 className="text-5xl font-heading font-bold text-text-title mb-4">
              Welcome to <span className="text-primary">autoUSD</span>
            </h1>
            <p className="text-lg text-text-muted max-w-2xl mx-auto">
              Consumer-first cross-chain yield optimization. Earn optimized yields on USDC across multiple L2 networks with automated rebalancing.
            </p>
            <div className="mt-8 flex gap-4 justify-center">
              <Button variant="primary" size="lg" pill>
                Get Started
              </Button>
              <Button variant="subtle" size="lg">
                Learn More
              </Button>
            </div>
          </div>

          {/* Glass Card Demo */}
          <Card glass elevation="md" className="p-8 mt-12">
            <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
              <div className="text-center">
                <h3 className="text-2xl font-heading font-bold text-primary mb-2">15.2%</h3>
                <p className="text-sm text-text-muted">Average APY</p>
              </div>
              <div className="text-center">
                <h3 className="text-2xl font-heading font-bold text-primary mb-2">$2.4M</h3>
                <p className="text-sm text-text-muted">Total Value Locked</p>
              </div>
              <div className="text-center">
                <h3 className="text-2xl font-heading font-bold text-primary mb-2">3</h3>
                <p className="text-sm text-text-muted">Active Networks</p>
              </div>
            </div>
          </Card>
        </div>
      </section>

      {/* Color Palette */}
      <section className="py-16 px-4 bg-surface">
        <div className="container mx-auto max-w-6xl">
          <h2 className="text-3xl font-heading font-bold text-text-title mb-8">Color Palette</h2>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            <div className="space-y-2">
              <div className="h-24 rounded-lg bg-primary"></div>
              <p className="text-sm font-medium">Primary</p>
              <p className="text-xs text-text-muted">#4CA8A1</p>
            </div>
            <div className="space-y-2">
              <div className="h-24 rounded-lg bg-secondary"></div>
              <p className="text-sm font-medium">Secondary</p>
              <p className="text-xs text-text-muted">#D6C7A1</p>
            </div>
            <div className="space-y-2">
              <div className="h-24 rounded-lg bg-success"></div>
              <p className="text-sm font-medium">Success</p>
              <p className="text-xs text-text-muted">#1AAE6F</p>
            </div>
            <div className="space-y-2">
              <div className="h-24 rounded-lg bg-error"></div>
              <p className="text-sm font-medium">Error</p>
              <p className="text-xs text-text-muted">#E25555</p>
            </div>
            <div className="space-y-2">
              <div className="h-24 rounded-lg border-2 border-border bg-surface"></div>
              <p className="text-sm font-medium">Surface</p>
              <p className="text-xs text-text-muted">#F3FAF8</p>
            </div>
            <div className="space-y-2">
              <div className="h-24 rounded-lg bg-mist"></div>
              <p className="text-sm font-medium">Mist</p>
              <p className="text-xs text-text-muted">#EAEFF2</p>
            </div>
          </div>
        </div>
      </section>

      {/* Dashboard Demo */}
      <section className="py-16 px-4">
        <div className="container mx-auto max-w-6xl">
          <h2 className="text-3xl font-heading font-bold text-text-title mb-8">Dashboard Components</h2>
          
          {/* Stats Grid */}
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
            <Stat 
              label="Katana Yield"
              value="18.5%"
              delta={{ value: "+2.3%", trend: "up" }}
              sparkline={sparklineData}
            />
            <Stat 
              label="Zircuit Yield"
              value="14.2%"
              delta={{ value: "-0.8%", trend: "down" }}
              sparkline={sparklineData.reverse()}
            />
            <Stat 
              label="Base Yield"
              value="12.9%"
              delta={{ value: "0%", trend: "neutral" }}
              sparkline={[15, 15, 15, 15, 15, 15, 15, 15]}
            />
          </div>

          {/* Positions Table Card */}
          <Card elevation="md">
            <CardHeader>
              <CardTitle>Your Positions</CardTitle>
              <Badge variant="positive">Active</Badge>
            </CardHeader>
            <CardContent>
              <div className="overflow-x-auto">
                <table className="w-full">
                  <thead>
                    <tr className="border-b border-border">
                      <th className="text-left py-3 px-4 text-sm font-medium text-text-muted">Network</th>
                      <th className="text-left py-3 px-4 text-sm font-medium text-text-muted">Amount</th>
                      <th className="text-left py-3 px-4 text-sm font-medium text-text-muted">APY</th>
                      <th className="text-left py-3 px-4 text-sm font-medium text-text-muted">Earnings</th>
                      <th className="text-left py-3 px-4 text-sm font-medium text-text-muted">Status</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr className="border-b border-border/50">
                      <td className="py-3 px-4">
                        <div className="flex items-center gap-2">
                          <div className="w-2 h-2 rounded-full bg-primary"></div>
                          <span className="font-medium">Katana</span>
                        </div>
                      </td>
                      <td className="py-3 px-4 tabular-nums">$5,000.00</td>
                      <td className="py-3 px-4 tabular-nums text-success">18.5%</td>
                      <td className="py-3 px-4 tabular-nums">+$125.30</td>
                      <td className="py-3 px-4">
                        <Badge variant="positive" size="sm">Active</Badge>
                      </td>
                    </tr>
                    <tr className="border-b border-border/50">
                      <td className="py-3 px-4">
                        <div className="flex items-center gap-2">
                          <div className="w-2 h-2 rounded-full bg-secondary"></div>
                          <span className="font-medium">Zircuit</span>
                        </div>
                      </td>
                      <td className="py-3 px-4 tabular-nums">$3,000.00</td>
                      <td className="py-3 px-4 tabular-nums text-warning">14.2%</td>
                      <td className="py-3 px-4 tabular-nums">+$56.70</td>
                      <td className="py-3 px-4">
                        <Badge variant="warning" size="sm">Rebalancing</Badge>
                      </td>
                    </tr>
                    <tr>
                      <td className="py-3 px-4">
                        <div className="flex items-center gap-2">
                          <div className="w-2 h-2 rounded-full bg-mist"></div>
                          <span className="font-medium">Base</span>
                        </div>
                      </td>
                      <td className="py-3 px-4 tabular-nums">$2,000.00</td>
                      <td className="py-3 px-4 tabular-nums">12.9%</td>
                      <td className="py-3 px-4 tabular-nums">+$34.20</td>
                      <td className="py-3 px-4">
                        <Badge variant="neutral" size="sm">Idle</Badge>
                      </td>
                    </tr>
                  </tbody>
                </table>
              </div>
            </CardContent>
            <CardFooter className="justify-between">
              <p className="text-sm text-text-muted">Total: $10,000.00</p>
              <Button variant="primary" size="sm">
                Deposit More
              </Button>
            </CardFooter>
          </Card>
        </div>
      </section>

      {/* Components Showcase */}
      <section className="py-16 px-4 bg-surface">
        <div className="container mx-auto max-w-6xl">
          <h2 className="text-3xl font-heading font-bold text-text-title mb-8">Component Library</h2>
          
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
            {/* Buttons */}
            <Card>
              <CardHeader>
                <CardTitle>Buttons</CardTitle>
                <CardDescription>Various button styles and states</CardDescription>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="flex flex-wrap gap-3">
                  <Button variant="primary">Primary</Button>
                  <Button variant="secondary">Secondary</Button>
                  <Button variant="subtle">Subtle</Button>
                  <Button variant="ghost">Ghost</Button>
                  <Button variant="link">Link</Button>
                </div>
                <div className="flex flex-wrap gap-3">
                  <Button size="sm">Small</Button>
                  <Button size="md">Medium</Button>
                  <Button size="lg">Large</Button>
                  <Button pill>Pill Shape</Button>
                  <Button loading>Loading</Button>
                  <Button disabled>Disabled</Button>
                </div>
              </CardContent>
            </Card>

            {/* Form Elements */}
            <Card>
              <CardHeader>
                <CardTitle>Form Elements</CardTitle>
                <CardDescription>Input fields and controls</CardDescription>
              </CardHeader>
              <CardContent className="space-y-4">
                <Input 
                  label="Email Address"
                  type="email"
                  placeholder="you@example.com"
                  value={formValues.email}
                  onChange={(e) => setFormValues({...formValues, email: e.target.value})}
                  helperText="We'll never share your email"
                />
                <Select
                  label="Select Network"
                  options={[
                    { value: "katana", label: "Katana" },
                    { value: "zircuit", label: "Zircuit" },
                    { value: "base", label: "Base" },
                  ]}
                  value={formValues.network}
                  onChange={(e) => setFormValues({...formValues, network: e.target.value})}
                />
                <Input 
                  label="Amount"
                  type="number"
                  placeholder="0.00"
                  error
                  errorMessage="Amount must be greater than 0"
                />
                <div className="space-y-3">
                  <Checkbox 
                    label="I agree to the terms and conditions"
                    checked={formValues.terms}
                    onChange={(e) => setFormValues({...formValues, terms: e.target.checked})}
                  />
                  <Toggle 
                    label="Enable notifications"
                    checked={formValues.notifications}
                    onChange={(e) => setFormValues({...formValues, notifications: e.target.checked})}
                  />
                </div>
              </CardContent>
            </Card>

            {/* Badges */}
            <Card>
              <CardHeader>
                <CardTitle>Badges</CardTitle>
                <CardDescription>Status indicators and labels</CardDescription>
              </CardHeader>
              <CardContent>
                <div className="flex flex-wrap gap-2">
                  <Badge variant="neutral">Neutral</Badge>
                  <Badge variant="positive">Positive</Badge>
                  <Badge variant="warning">Warning</Badge>
                  <Badge variant="error">Error</Badge>
                  <Badge variant="primary">Primary</Badge>
                  <Badge variant="secondary">Secondary</Badge>
                </div>
              </CardContent>
            </Card>

            {/* Loading States */}
            <Card>
              <CardHeader>
                <CardTitle>Loading States</CardTitle>
                <CardDescription>Skeleton loaders for content</CardDescription>
              </CardHeader>
              <CardContent className="space-y-4">
                <Skeleton height={40} />
                <Skeleton variant="text" />
                <div className="flex gap-4">
                  <Skeleton variant="circular" width={40} height={40} />
                  <div className="flex-1 space-y-2">
                    <Skeleton variant="text" width="60%" />
                    <Skeleton variant="text" width="40%" />
                  </div>
                </div>
              </CardContent>
            </Card>
          </div>

          {/* Empty and Error States */}
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-8 mt-8">
            <Card>
              <EmptyState
                icon={
                  <svg className="h-12 w-12" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} 
                      d="M20 13V6a2 2 0 00-2-2H6a2 2 0 00-2 2v7m16 0v5a2 2 0 01-2 2H6a2 2 0 01-2-2v-5m16 0h-2.586a1 1 0 00-.707.293l-2.414 2.414a1 1 0 01-.707.293h-3.172a1 1 0 01-.707-.293l-2.414-2.414A1 1 0 006.586 13H4" 
                    />
                  </svg>
                }
                title="No positions yet"
                description="Start earning yield by depositing USDC into autoUSD"
                action={{
                  label: "Make First Deposit",
                  onClick: () => console.log("Deposit clicked")
                }}
              />
            </Card>

            <Card>
              <ErrorState
                title="Transaction Failed"
                description="Your transaction could not be processed"
                error="Insufficient balance in wallet"
                action={{
                  label: "Try Again",
                  onClick: () => console.log("Retry clicked")
                }}
              />
            </Card>
          </div>
        </div>
      </section>

      {/* Typography */}
      <section className="py-16 px-4">
        <div className="container mx-auto max-w-6xl">
          <h2 className="text-3xl font-heading font-bold text-text-title mb-8">Typography</h2>
          <Card>
            <CardContent className="space-y-4 py-8">
              <h1 className="text-5xl font-heading font-bold">Heading 1 - Poppins Bold</h1>
              <h2 className="text-4xl font-heading font-bold">Heading 2 - Poppins Bold</h2>
              <h3 className="text-3xl font-heading font-semibold">Heading 3 - Poppins Semibold</h3>
              <h4 className="text-2xl font-heading font-semibold">Heading 4 - Poppins Semibold</h4>
              <h5 className="text-xl font-heading font-semibold">Heading 5 - Poppins Semibold</h5>
              <h6 className="text-lg font-heading font-semibold">Heading 6 - Poppins Semibold</h6>
              <div className="divider"></div>
              <p className="text-base">
                Body text uses Inter for optimal readability. This is a paragraph demonstrating the base font size and line height. 
                The clean, modern aesthetic supports our consumer-first approach.
              </p>
              <p className="text-sm text-text-muted">
                Small text for supporting information and helper text.
              </p>
              <p className="text-lg font-medium">
                Large text with medium weight for emphasis.
              </p>
              <p className="tabular-nums text-2xl font-semibold">
                1,234,567.89 USDC
              </p>
            </CardContent>
          </Card>
        </div>
      </section>
    </div>
  );
}
'use client';

import { useMemo, useState } from 'react';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Area, AreaChart, Dot } from 'recharts';
import { useAPYHistory } from '@/hooks/useAPYHistory';

interface APYChartProps {
  timeframe: '24h' | '7d' | '30d';
}

interface CustomTooltipProps {
  active?: boolean;
  payload?: any[];
  label?: string;
}

function CustomTooltip({ active, payload, label }: CustomTooltipProps) {
  if (active && payload && payload[0]) {
    return (
      <div className="bg-white shadow-lg border border-border/50 rounded-lg p-3">
        <p className="text-xs text-text-muted mb-1">{label}</p>
        <p className="text-lg font-heading font-semibold text-text-title">
          {payload[0].value.toFixed(2)}%
        </p>
        <p className="text-xs text-success mt-1">Annual Rate</p>
      </div>
    );
  }
  return null;
}

function CustomDot(props: any) {
  const { cx, cy, index, dataLength } = props;
  if (index === dataLength - 1) {
    return (
      <g>
        <circle cx={cx} cy={cy} r={4} fill="#4CA8A1" stroke="#fff" strokeWidth={2} />
        <circle cx={cx} cy={cy} r={8} fill="#4CA8A1" fillOpacity={0.2}>
          <animate attributeName="r" from="8" to="12" dur="1.5s" repeatCount="indefinite" />
          <animate attributeName="fill-opacity" from="0.2" to="0" dur="1.5s" repeatCount="indefinite" />
        </circle>
      </g>
    );
  }
  return null;
}

export function APYChart({ timeframe }: APYChartProps) {
  const { data, isLoading } = useAPYHistory(timeframe);
  const [hoveredPoint, setHoveredPoint] = useState<number | null>(null);

  const chartData = useMemo(() => {
    if (!data) {
      // Generate realistic demo data
      const now = Date.now();
      const points = timeframe === '24h' ? 24 : timeframe === '7d' ? 7 : 30;
      const interval = timeframe === '24h' ? 3600000 : 86400000;
      
      return Array.from({ length: points }, (_, i) => {
        const baseAPY = 10;
        const variation = Math.sin(i * 0.5) * 0.3 + Math.random() * 0.2;
        return {
          time: new Date(now - (points - i - 1) * interval).toLocaleDateString('en-US', {
            month: 'short',
            day: 'numeric',
            hour: timeframe === '24h' ? '2-digit' : undefined,
          }),
          apy: baseAPY + variation,
          timestamp: now - (points - i - 1) * interval,
        };
      });
    }
    
    return data.map(point => ({
      time: new Date(point.timestamp).toLocaleDateString('en-US', {
        month: 'short',
        day: 'numeric',
        hour: timeframe === '24h' ? '2-digit' : undefined,
      }),
      apy: point.apy,
      base: point.chainAPYs.base,
      katana: point.chainAPYs.katana,
      zircuit: point.chainAPYs.zircuit,
      timestamp: point.timestamp,
    }));
  }, [data, timeframe]);

  if (isLoading) {
    return (
      <div className="h-64 flex items-center justify-center">
        <div className="animate-pulse bg-gradient-to-r from-primary-subtle to-accent-mist rounded-lg w-full h-full"></div>
      </div>
    );
  }

  return (
    <div className="relative">
      {/* Y-axis label */}
      <div className="absolute -left-2 top-0 text-xs text-text-muted -rotate-90 origin-left translate-y-8">
        APY %
      </div>
      
      <ResponsiveContainer width="100%" height={256}>
        <AreaChart 
          data={chartData} 
          margin={{ top: 10, right: 10, left: 10, bottom: 20 }}
          onMouseMove={(e: any) => {
            if (e && e.activeTooltipIndex !== undefined) {
              setHoveredPoint(e.activeTooltipIndex);
            }
          }}
          onMouseLeave={() => setHoveredPoint(null)}
        >
          <defs>
            <linearGradient id="apyGradient" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor="#4CA8A1" stopOpacity={0.4}/>
              <stop offset="50%" stopColor="#72D1CB" stopOpacity={0.2}/>
              <stop offset="100%" stopColor="#D6C7A1" stopOpacity={0}/>
            </linearGradient>
            <filter id="glow">
              <feGaussianBlur stdDeviation="3" result="coloredBlur"/>
              <feMerge>
                <feMergeNode in="coloredBlur"/>
                <feMergeNode in="SourceGraphic"/>
              </feMerge>
            </filter>
          </defs>
          
          <CartesianGrid 
            strokeDasharray="0" 
            stroke="#E8F6F5" 
            vertical={false}
          />
          
          <XAxis 
            dataKey="time" 
            stroke="#5C6B6A"
            fontSize={11}
            tickLine={false}
            axisLine={{ stroke: '#D9E6E3' }}
            dy={10}
          />
          
          <YAxis 
            stroke="#5C6B6A"
            fontSize={11}
            tickLine={false}
            axisLine={false}
            tickFormatter={(value) => `${value}%`}
            domain={['dataMin - 0.5', 'dataMax + 0.5']}
          />
          
          <Tooltip 
            content={<CustomTooltip />}
            cursor={{ stroke: '#4CA8A1', strokeWidth: 1, strokeDasharray: '3 3' }}
          />
          
          <Area 
            type="monotone" 
            dataKey="apy" 
            stroke="#4CA8A1" 
            strokeWidth={2.5}
            fill="url(#apyGradient)"
            filter="url(#glow)"
            dot={(props: any) => <CustomDot {...props} dataLength={chartData.length} />}
            activeDot={{ r: 6, fill: '#4CA8A1', stroke: '#fff', strokeWidth: 2 }}
          />
        </AreaChart>
      </ResponsiveContainer>
      
      {/* X-axis label */}
      <div className="text-center text-xs text-text-muted mt-2">
        {timeframe === '24h' ? 'Last 24 Hours' : timeframe === '7d' ? 'Last 7 Days' : 'Last 30 Days'}
      </div>
    </div>
  );
}
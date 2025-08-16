'use client';

import { useMemo } from 'react';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Area, AreaChart } from 'recharts';
import { useAPYHistory } from '@/hooks/useAPYHistory';

interface APYChartProps {
  timeframe: '24h' | '7d' | '30d';
}

export function APYChart({ timeframe }: APYChartProps) {
  const { data, isLoading } = useAPYHistory(timeframe);

  const chartData = useMemo(() => {
    if (!data) return [];
    
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
    }));
  }, [data, timeframe]);

  if (isLoading) {
    return (
      <div className="h-64 flex items-center justify-center">
        <div className="animate-pulse bg-gray-200 rounded w-full h-full"></div>
      </div>
    );
  }

  return (
    <ResponsiveContainer width="100%" height={256}>
      <AreaChart data={chartData} margin={{ top: 10, right: 30, left: 0, bottom: 0 }}>
        <defs>
          <linearGradient id="colorAPY" x1="0" y1="0" x2="0" y2="1">
            <stop offset="5%" stopColor="#3B82F6" stopOpacity={0.3}/>
            <stop offset="95%" stopColor="#3B82F6" stopOpacity={0}/>
          </linearGradient>
        </defs>
        <CartesianGrid strokeDasharray="3 3" stroke="#E5E7EB" />
        <XAxis 
          dataKey="time" 
          stroke="#9CA3AF"
          fontSize={12}
          tickLine={false}
        />
        <YAxis 
          stroke="#9CA3AF"
          fontSize={12}
          tickLine={false}
          tickFormatter={(value) => `${value}%`}
        />
        <Tooltip 
          contentStyle={{ 
            backgroundColor: 'white',
            border: '1px solid #E5E7EB',
            borderRadius: '8px',
            padding: '8px'
          }}
          formatter={(value: number) => [`${value.toFixed(2)}%`, 'APY']}
        />
        <Area 
          type="monotone" 
          dataKey="apy" 
          stroke="#3B82F6" 
          strokeWidth={2}
          fill="url(#colorAPY)"
        />
      </AreaChart>
    </ResponsiveContainer>
  );
}
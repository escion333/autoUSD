'use client';

import { useState, useEffect } from 'react';

interface APYDataPoint {
  timestamp: number;
  apy: number;
  chainAPYs: {
    base: number;
    katana: number;
    zircuit: number;
  };
}

export function useAPYHistory(timeframe: '24h' | '7d' | '30d') {
  const [data, setData] = useState<APYDataPoint[]>([]);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    // Generate mock historical data
    const generateData = () => {
      const points: APYDataPoint[] = [];
      const now = Date.now();
      
      let numPoints: number;
      let interval: number;
      
      switch (timeframe) {
        case '24h':
          numPoints = 24;
          interval = 60 * 60 * 1000; // 1 hour
          break;
        case '7d':
          numPoints = 7;
          interval = 24 * 60 * 60 * 1000; // 1 day
          break;
        case '30d':
          numPoints = 30;
          interval = 24 * 60 * 60 * 1000; // 1 day
          break;
      }

      for (let i = numPoints - 1; i >= 0; i--) {
        const timestamp = now - (i * interval);
        
        // Generate realistic APY values with some variance
        const baseAPY = 8.5 + (Math.random() - 0.5) * 2;
        const katanaAPY = 12.5 + (Math.random() - 0.5) * 3;
        const zircuitAPY = 9.5 + (Math.random() - 0.5) * 2.5;
        
        // Calculate weighted average (assuming equal allocation for simplicity)
        const averageAPY = (baseAPY + katanaAPY + zircuitAPY) / 3;
        
        points.push({
          timestamp,
          apy: averageAPY,
          chainAPYs: {
            base: baseAPY,
            katana: katanaAPY,
            zircuit: zircuitAPY,
          },
        });
      }
      
      return points;
    };

    setIsLoading(true);
    // Simulate API delay
    setTimeout(() => {
      setData(generateData());
      setIsLoading(false);
    }, 500);
  }, [timeframe]);

  return { data, isLoading };
}